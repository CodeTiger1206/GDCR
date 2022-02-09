function [ x,y ] = mobility( x, y, len, dir )
%UNTITLED3 Summary of this function goes here
%   函数处理节点的移动性
%   x - x coordinate
%   y - y coordinate
%   len - length of the movement
%   dir - degree to move [0..360]


x=x+(len*cosd(dir));
y=y+(len*sind(dir));

end

