function P = canget(A)

%   �ж�ͼ����ͨ��,����A�Ŀɴ��Ծ���
    n = length(A);
    P = A;
    for i=2:n
        P = P + A^i;
    end
    P=(P~=0);
end

