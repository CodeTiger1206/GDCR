function [ angle ] = Cangle(x1,y1,x2,y2)

%   计算两点之间的角度
    if x1 == x2
        if y1 < y2
            angle = pi * 0.5;
        else
            angle = pi * 1.5;
        end
    elseif y1 == y2
      if x1 < x2
        angle = 0;
      else
        angle = pi;
      end
    else    
      Result = atan((y1 - y2)/(x1 - x2));
      if x2 < x1 && y2 > y1
        angle = Result + pi;
      elseif x2 < x1 && y2 < y1
        angle = Result + pi;
      elseif x2 > x1 && y2 < y1
        angle = Result + 2 * pi;
      else
        angle = Result;     
      end    
    end
    angle = angle*(180/pi);
end

