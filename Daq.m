classdef Daq<handle

    
    properties (Access = public)      
       vars;
       p;
       resMat;
       debugStatus;
       isConnected;
       maxValue = 4096;
       maxVolt = 0.02;
       minVolt = -0.02;
    end
    
    methods
        function this = Daq()
            this.vars.numOfSamples = 2030;
            this.vars.sampleLength = 2032;
            this.vars.channels = 256;
            this.vars.delay = 0;
            this.vars.filterBandwidth = 'max';
            this.vars.coupling = 50;
            this.vars.samplingRate = 125e6;
            this.vars.numOfFrames = 1;
            this.vars.ADCGain = 0;
            this.debugStatus = 'disabled';
            this.isConnected = 'notConnected';
            
           if ~libisloaded('IALibrary')
              loadlibrary('IALibrary.dll', 'IALibrary.h');
              libfunctions('IALibrary');
           end 
           
            if ( calllib('IALibrary', 'isDeviceConnected') == 0 )
                if( this.connect() ~= 0)
                   error('Daq object can not connect to the device./n The DAQ might be already in use'); 
                end
                isCon = 1;
            else
                isCon = 0;
            end
            setSamplingRate(this, this.vars.samplingRate);
            setDelay(this, this.vars.delay);
            setCoupling(this, this.vars.coupling);
            setNumOfFrames(this, this.vars.numOfFrames);
            setNumOfSamples(this, this.vars.numOfSamples);
            setFilterBandwidth(this, this.vars.filterBandwidth);
            setADCGain(this, this.vars.ADCGain);
            if ( isCon == 1 )
                this.disconnect();
            end
            initDataStructures(this);

        end
        
        function r = connect(this)
            if ~libisloaded('IALibrary')
                msg = 'Library is unloaded';
                error(msg);
            end

            if calllib('IALibrary', 'isDeviceConnected') == 1
                disp('Device is already connected');
                r = 0;
                return;
            end
            r = calllib('IALibrary', 'connect');
            this.isConnected = 'Connected';
        end
        
        function r = disconnect(this)
            if ~libisloaded('IALibrary')
              msg = 'Library is unloaded';
              error(msg);
            end
            
            if calllib('IALibrary', 'isDeviceConnected') == 0
              disp('Device is already disconnected');
              r = 0;
              return;
            end
            
            r = calllib('IALibrary', 'disconnect');
            this.isConnected = 'notConnected';
        end
        
        function resMat = acquire(this)
            if ~libisloaded('IALibrary')
              msg = 'Library is unloaded';
              error(msg);
            end
            
            if calllib('IALibrary', 'isDeviceConnected') == 0
              error('Device is not connected');
            end
            
            ret = calllib('IALibrary', 'acquireIm', this.p);

            data = this.p.value;
            
            for i = 1 : this.vars.numOfFrames
                temp = reshape(typecast(data(this.vars.sampleLength*this.vars.channels*2*(i-1) + 1:this.vars.sampleLength*this.vars.channels*2*i), 'uint16'), this.vars.sampleLength, this.vars.channels);
                this.resMat(:,:,i) = temp(3:end,:);
            end

           
            resMat = this.resMat;
        end
        
        function resMat = channelsFilteringAcquire(this, mask)
            resMat = this.acquire();
            l = length(mask);
            i = 1;
            while(i <= l)
                if(mask(i) == 0)
                  resMat(:,i,:) = [];
                  mask(i) = [];
                  l = length(mask);
                else
                    i = i + 1;
                end
                
            end
            for i = 1 : length(mask)
               if(mask(i) == 0)
                  resMat(:,i,:) = [];
                  mask(i) = [];
               end
            end
        end

        function res = setSamplingRate(this, rate)  
            
            if ~libisloaded('IALibrary')
              msg = 'Library is unloaded';
              error(msg);
           end
            
            if calllib('IALibrary', 'isDeviceConnected') == 0
              error('Device is not connected');
            end
           
            switch rate
                case 40e6
                    this.vars.samplingRate = rate;
                    calllib('IALibrary', 'SetSamplingRate', 0);
                    res = 0;
                case 125e6
                    this.vars.samplingRate = rate;
                    calllib('IALibrary', 'SetSamplingRate', 1);
                    res = 0;
                otherwise
                    res = -1;
                   error('Input value of sampling rate is invalid. Value must be 40 or 125');
            end
        end
        
        function res = setDelay(this, d)
            if calllib('IALibrary', 'isDeviceConnected') == 0
              error('Device is not connected');
           end
           if(floor(d) ~= d)
               res = -1;
              error('Delay value must be an integer'); 
           end
           
           if(d < 0 || d > 199)
              res = -1;
              error('Delay value must be in the interval [0,199]');
           end
           
           calllib('IALibrary', 'SetDelay', d);
           this.vars.delay = d;
           res = 0;
        end
        
        function res = setCoupling(this, c)
            if calllib('IALibrary', 'isDeviceConnected') == 0
              error('Device is not connected');
           end
           switch c
               case 50
                   calllib('IALibrary', 'SetCoupling', 0);
                   this.vars.coupling = 50;
                   res = 0;
               case 'HighZ'
                   calllib('IALibrary', 'SetCoupling', 1);
                   this.vars.coupling = HighZ;
                   res = 0;
               otherwise
                   res = -1;
                   error('Coupling value must be 50 or HighZ');
           end
        end
        
        function res = setADCGain(this, v)
            if calllib('IALibrary', 'isDeviceConnected') == 0
               res = -1; 
               error('Device is not connected');
            end
           
            if(floor(v) ~= v)
                res = -1;
               error('ADCGain value must be integer'); 
            end
            
            if ( v > 128 || v < 0)
                res = -1;
               error('ADCGain value must be between 0 and 128'); 
            end
            
            calllib('IALibrary', 'SetADCGain', v);
            this.vars.ADCGain = v;
            res = 0;
        end
        
        function res = setNumOfFrames(this, nos)
            if calllib('IALibrary', 'isDeviceConnected') == 0
              error('Device is not connected');
           end
           if(floor(nos) ~= nos || nos <= 0)
               res = -1;
              error('Number of samples must be a positive integer'); 
           end
           
           this.vars.numOfFrames = nos;
           calllib('IALibrary', 'SetNumOfFrames', nos);
           this.initDataStructures();
           res = 0;
        end
        
        function res = setNumOfSamples(this, len)
            if calllib('IALibrary', 'isDeviceConnected') == 0
              error('Device is not connected');
            end
 
           switch len
               case 2030
                   this.vars.numOfSamples = len;
                   this.vars.sampleLength = len+2;
                   calllib('IALibrary', 'SetSamplelength', 0);
                   res = 0;
               case 1008
                   this.vars.numOfSamples = len;
                   this.vars.sampleLength = len+2;
                   calllib('IALibrary', 'SetSamplelength', 1);
                   res = 0;
               case 496
                   this.vars.numOfSamples = len;
                   this.vars.sampleLength = len+2;
                   calllib('IALibrary', 'SetSamplelength', 2);
                   res = 0;
               otherwise
                   res = -1;
                   error('Input value is invalid');
           end
           initDataStructures(this);
        end
        
        function res = setFilterBandwidth(this, fb)
            if calllib('IALibrary', 'isDeviceConnected') == 0
              error('Device is not connected');
            end
            
            switch fb
                case 'max'
                    calllib('IALibrary', 'SetFilterBandwidth', 0);
                    this.vars.filterBandwidth = 'max';
                case '20M'
                     calllib('IALibrary', 'SetFilterBandwidth', 1);
                     this.vars.filterBandwidth = '20M';
                otherwise
                    error('invalid value');
            end
           res = 0;
        end
        
        function res = RequestDebug(this)
            calllib('IALibrary', 'RequestDebug');
            this.debugStatus = 'enabled';
            res = 0;
        end

        function res = AbortDebug(this)
            calllib('IALibrary', 'AbortDebug');
            this.debugStatus = 'disabled';
            res = 0;
        end

        function setVars(this, uVars)
            if calllib('IALibrary', 'isDeviceConnected') == 0
              error('Device is not connected');
            end
            
            setSamplingRate(this, uVars.samplingRate);
            setDelay(this, uVars.delay);
            setCoupling(this, uVars.coupling);
            setNumOfFrames(this, uVars.numOfFrames);
            setNumOfSamples(this, uVars.numOfSamples);
            setFilterBandwidth(this, uVars.filterBandwidth);
            setADCGain(this, uVars.ADCGain);
            
            this.p = libpointer('uint8Ptr', zeros(this.vars.sampleLength * this.vars.numOfFrames* this.vars.channels*2, 1, 'uint8'));
            this.resMat = zeros(this.vars.numOfSamples, this.vars.channels, this.vars.numOfFrames);
        end
        
        function initDataStructures(this)
           this.p = libpointer('uint8Ptr', zeros((this.vars.sampleLength)  * this.vars.numOfFrames,this.vars.channels*2, 'uint8'));
           this.resMat = zeros(this.vars.numOfSamples, this.vars.channels, this.vars.numOfFrames);
        end
         
        function v = ToVolts(this, a)
            v = ( (this.maxVolt - this.minVolt) / this.maxValue ) * a + this.minVolt;
        end
        
    end
    
end

