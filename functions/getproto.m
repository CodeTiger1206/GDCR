function [ proto ] = getproto( s )
%GETPROTO Summary of this function goes here
%   Function parses .ini file for protocols
%   used in simulation and returns it as cell array
%   函数解析模拟中使用的协议的.ini文件，并将其作为单元数组返回
  
n = size(s);
str = s;
proto = {};
while n > 0    
    [Key,Val] = strtok(str, ' ');
    Val = strtrim(Val(2:end)); 
    n = size(Key);
    str = Val;
    proto = [proto Key];
end
end

