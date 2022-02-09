function P = canget(A)

%   判断图的连通性,返回A的可达性矩阵
    n = length(A);
    P = A;
    for i=2:n
        P = P + A^i;
    end
    P=(P~=0);
end

