classdef MissionModel < handle
    %   自定义的移动模型，刘
    
    properties 
       %time
       speed
       dir 
    end
    
    properties (Access = private)
       maxspeed
    end
    
    methods
        function obj = MissionModel(speed)
            obj = obj.direction(speed);
            obj.maxspeed = speed;
         
        end 
        
        function obj = direction(obj,speed)
            obj.speed = speed; % node movement speed
            obj.dir = 0;     % node direction, degrees            
        end
        
        function s = get.speed( obj )
            s = obj.speed;
        end        
        
        function d = get.dir( obj )
            d = obj.dir;
        end                
    end
    
end

