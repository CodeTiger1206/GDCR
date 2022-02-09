function ans = isCritical(Neighbors,radio)
%����һ���ھ���Ϣ�жϸýڵ��Ƿ����ڹؼ��ڵ�
%ÿ���ڵ�����ھӵ�λ����Ϣ�ڱ���ȷ�����Ƿ���Ҫ��
%�������ھӵ�λ�ü�������֮��ľ��롣�������С�����ǵ�ͨ�ŷ�Χ����ڵ㱻��Ϊ�Ƿǹؼ��ģ�

neighbors = [];
for i=1:size(Neighbors,1)
    if Neighbors(i,1)~=0 && Neighbors(i,2)~=0
        neighbors = [neighbors;[Neighbors(i,1) Neighbors(i,2)]];
    end
end

[m,n] = size(neighbors);
if m==0 || m==1 %���ֻ��һ���ھ���ýڵ㲻���ڹؼ��ڵ�
    ans = 0;
    return;
end

A = zeros(m); %���������ھӽڵ���ڽӾ���

for i=1:m
    for j=1:m
        if i~=j
            x1 = neighbors(i,1);
            y1 = neighbors(i,2);
            x2 = neighbors(j,1);
            y2 = neighbors(j,2);

            range=sqrt((x2-x1)^2+(y2-y1)^2);
            if (range)<radio 
                A(i,j)=1;
            else        
                A(i,j)=0;
            end
        else
            A(i,i)=0;
        end
    end
end

P = canget(A);
if all(P(:)==1)==0 %�ж���ͨ��
    ans = 1; %�����е�һ���ھ�֮�䲻��ͨ����ýڵ��ǹؼ��ڵ�
else
    ans = 0; %�����е�һ���ھ�֮����ͨ����ýڵ㲻�ǹؼ��ڵ�
end

end

