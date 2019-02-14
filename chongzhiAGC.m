function [Old,New] = chongzhiAGC(AGC,P,Pall)
% This is the file for calculating the revenue
% AGC  AGCָ��
% Pall  ����
% P     ����
% Pbat  ����

global day_agcresult
%%%%%%%���������ļ�ʱ��Ҫ���ص�����%%%%%%%%
% clear
% load('XFdata')
% data=XFdata.data1215;
% AGC=data(:,1);
% Pall=data(:,3);
% P=data(:,2);
%%%%%%%���������ļ�ʱ��Ҫ���ص�����%%%%%%%%

len=length(AGC);
Result=zeros(1,19);
%Result=[AGC Pt0 T0 Pt1 T1 Pt2 T2 Pt3 T3 Tj Vj detP K1 K2 K3 Kp D  flag Validity];
%Result=[ 1   2  3  4   5  6   7   8  9  10 11  12  13 14 15 16 17  18  19];
ControlNo=1;
Result(ControlNo,1:3)=[AGC(1) Pall(1) 1];
if Result(ControlNo,1)>Result(ControlNo,2)
    % ���ϵ���
    flag=1;
    Result(ControlNo,18)=flag;
else
    % ���µ���
    flag=-1;
    Result(ControlNo,18)=flag;
end
Pe=300;%��������
deadzone1=Pe*0.012;%��Ӧ����0.01,2
deadzone2=Pe*0.01;%��������0.01,2
% deadzone3=0.01;%ָ������
Vn=Pe*0.015;%��׼�����ٶ�MW/min,Pe*0.015
tn=60;%��׼����ʱ��s
detPn=0.008*Pe;%��׼���ھ���0.01*Pe(3)
scanrate=5;%ɨ��Ƶ��
for i=1:scanrate:len
    if abs(AGC(i)-Result(ControlNo,1))>=2 %deadzone3*Pe %Pe*0.01
        % ��AGC��ǰֵ>��¼AGCֵ+2(����Pe*0.01)������AGC�����˶��������ܳ�����һ���µ�AGC
        % ����Ҫ������һ��AGC��Kֵ���Լ��ж���һ��AGCָ���Ƿ���Ч

        % ��¼T3
        % ��¼Pt3
        Result(ControlNo,8)=Pall(i-scanrate);
        Result(ControlNo,9)=i-scanrate;
        % û��Ѱ�ҵ�T1���Խ���ʱ�̼�
        if Result(ControlNo,5)==0
            Result(ControlNo,4)=Pall(i-scanrate);
            Result(ControlNo,5)=i-scanrate;
        end
        % û��Ѱ�ҵ�T2���Խ���ʱ�̼�
        if Result(ControlNo,7)==0
            Result(ControlNo,6)=Pall(i-scanrate);
            Result(ControlNo,7)=i-scanrate;
        end
        % ���T2<T1����T2=T1
        if Result(ControlNo,7)<Result(ControlNo,5)
            Result(ControlNo,7)=Result(ControlNo,5);
        end
        % ����������D
        % D=Pt2-Pt0+�۷�
        if  ControlNo~=1 && Result(ControlNo,18)*Result(ControlNo-1,18)>0 
            % ����ʱ����۷�
            Result(ControlNo,17)= flag*(Result(ControlNo,6)-Result(ControlNo,2));
        elseif ControlNo==1
            % ��һ��ָ����۷�����
            Result(ControlNo,17)= flag*(Result(ControlNo,6)-Result(ControlNo,2));
        else
            % ����ʱ��Ϊ�۷�
            Result(ControlNo,17)= flag*(Result(ControlNo,6)-Result(ControlNo,2))+Pe*0.02;
        end
        % ������һ��ָ����ٶ�Vj
        if Result(ControlNo,7)-Result(ControlNo,5)~=0
            % �����ӣ���ĸ��Ϊ0ʱ,����ʽ����
            Result(ControlNo,11)= flag*(Result(ControlNo,6)-Result(ControlNo,4))/(Result(ControlNo,7)-Result(ControlNo,5));%MW/s
            Result(ControlNo,11)= Result(ControlNo,11)*60;%MW/min
        else
            % �����Ӻͷ�ĸΪ0ʱ�����������D/ָ��ʱ��T����
            Result(ControlNo,11)= Result(ControlNo,17)/(Result(ControlNo,9)-Result(ControlNo,3));
            Result(ControlNo,11)= Result(ControlNo,11)*60;%MW/min
        end
        % ָ����Ч���ж�
        if Result(ControlNo,9)-Result(ControlNo,3)<=30 ...
            || abs(Result(ControlNo,1)-Result(ControlNo,2))<=Pe*0.01 ...
               || Result(ControlNo,11)>5*Vn
            % ��AGC����ʱ��<=30s
            % ��ָ������
            % ����ʼʱ��AGC-Pall<=����������1%
            % ��ָ������
            % �������ٶȴ���5���ο�����
            % ��ָ������,����Ϊ0
            Result(ControlNo,:)=0;
            % ControlNo=ControlNo+1;
        else
            %%======= ����K3 =======%%
            % Tj=T1-T0
            % K3=(0.1,2-Tj/60)
            Result(ControlNo,10)= Result(ControlNo,5)-Result(ControlNo,3);
            Result(ControlNo,15)= max(0.1,2-Result(ControlNo,10)/tn);
            %%======== ����K1 ========%%
            % K1=Vj/Vn or K1=(0.1,Vj/Vn)
            Result(ControlNo,13)= Result(ControlNo,11)/Vn;
            if Result(ControlNo,13)>4.2 %|| Result(ControlNo,13)<0.1
                Result(ControlNo,13)=0.1;
            end
%             if Result(ControlNo,11)<2*Vn
%                 % ����ͳ����Ϣ��Vj<2*Vn�������㣬����Ϊ0.1
%                 Result(ControlNo,13)= max(0.1,Result(ControlNo,11)/Vn);
%             else
%                 Result(ControlNo,13)= 0.1;
%             end
%            Result(ControlNo,13)= max(0.1,Result(ControlNo,13));
%            if Result(ControlNo,13)>2
%                Result(ControlNo,13)=2;
%            end
            %%======== ����K2 ========%%
            % detp=abs(p-agc)*dt/time
            % K2=2-detp/detPn
            if Result(ControlNo,7)- Result(ControlNo,9)~=0
                for m= Result(ControlNo,7):scanrate:Result(ControlNo,9)
                    Result(ControlNo,12)= Result(ControlNo,12)+abs(Pall(m)-Result(ControlNo,1))*scanrate;
                end
                Result(ControlNo,12)=Result(ControlNo,12)/(Result(ControlNo,9)-Result(ControlNo,7));
            else
                Result(ControlNo,12)=abs(Result(ControlNo,8)-Result(ControlNo,1));
            end
            Result(ControlNo,14)=max(0.1,2-Result(ControlNo,12)/detPn);
            %%========= ����Kp =========%%
            % ����Kp
            Result(ControlNo,16)=Result(ControlNo,13)*Result(ControlNo,14)*Result(ControlNo,15);
            % ������һ�ε�ָ�����
            Result(ControlNo,19)=1;
            ControlNo=ControlNo+1;
        end
        Result(ControlNo,1:3)=[AGC(i) Pall(i) i];
        if Result(ControlNo,1)>Result(ControlNo,2)
            % ���ϵ���
            flag=1;
            Result(ControlNo,18)=flag;
        else
            % ���µ���
            flag=-1;
            Result(ControlNo,18)=flag;
        end
    else
        % ��ǰAGC<��¼AGCֵ+Pe*0.01����������û�и����µ�AGCָ��
        % �������¼������¼AGC�µĲ�����
        if Result(ControlNo,5)==0 && abs(Pall(i)-Result(ControlNo,2))>=deadzone1 %deadzone1*Result(ControlNo,2)
            % ������iʱ����-��ʼ������>��Ӧ���� && ֮ǰû�м�¼����Ӧ��Ϣ
            % &&���������ֻ��¼һ�λ���Ϣ
            Result(ControlNo,4)=Pall(i);
            Result(ControlNo,5)=i;
        end
        if Result(ControlNo,7)==0 && abs(Pall(i)-Result(ControlNo,1))<=deadzone2 %deadzone1*Result(ControlNo,2)
            % ������iʱ����-AGCָ�<�������� && ֮ǰû�м�¼������������Ϣ
            Result(ControlNo,6)=Pall(i);
            Result(ControlNo,7)=i;
        end
    end
    
    %%%=====���һ�����ݵļ���=====%%%
    if i>=len-4 && i<=len
        % ��¼T3
        % ��¼Pt3
        Result(ControlNo,8)=Pall(i);
        Result(ControlNo,9)=i;
        % û��Ѱ�ҵ�T1���Խ���ʱ�̼�
        if Result(ControlNo,5)==0
            Result(ControlNo,4)=Pall(i);
            Result(ControlNo,5)=i;
        end
        % û��Ѱ�ҵ�T2���Խ���ʱ�̼�
        if Result(ControlNo,7)==0
            Result(ControlNo,6)=Pall(i);
            Result(ControlNo,7)=i;
        end
        % ����������D
        if  ControlNo~=1 && Result(ControlNo,18)*Result(ControlNo-1,18)>0 
            % ����ʱ����۷�
            Result(ControlNo,17)= flag*(Result(ControlNo,8)-Result(ControlNo,2));
        else
            % ����ʱ��Ϊ�۷�
            Result(ControlNo,17)= flag*(Result(ControlNo,8)-Result(ControlNo,2))+Pe*0.02;
        end
        % ������һ��ָ����ٶ�Vj
        if Result(ControlNo,7)-Result(ControlNo,5)~=0
            % �����ӣ���ĸ��Ϊ0ʱ,����ʽ����
            Result(ControlNo,11)= flag*(Result(ControlNo,6)-Result(ControlNo,4))/(Result(ControlNo,7)-Result(ControlNo,5));%MW/s
            Result(ControlNo,11)=  Result(ControlNo,11)*60;%MW/min
        else
            % �����Ӻͷ�ĸΪ0ʱ�����������D/ָ��ʱ��T����
            Result(ControlNo,11)= Result(ControlNo,17)/(Result(ControlNo,9)-Result(ControlNo,3));
            Result(ControlNo,11)=  Result(ControlNo,11)*60;%MW/min
        end
        % ָ����Ч���ж�
        if Result(ControlNo,9)-Result(ControlNo,3)<=30 ...
            || abs(Result(ControlNo,1)-Result(ControlNo,2))<=Pe*0.01 ...
               || Result(ControlNo,11)>5*Vn
            % ��AGC����ʱ��<=30
            % ��ָ������
            % ����ʼʱ��AGC-Pall<=����������1%
            % ��ָ������
            % �������ٶȴ���5���ο�����
            % ��ָ������
            Result(ControlNo,:)=0;
            Result(ControlNo,:)=[];
        else
            % ����K3
            % Tj=T1-T0
            % K3=(0.1,2-Tj/60)
            Result(ControlNo,10)= (Result(ControlNo,5)-Result(ControlNo,3));
            Result(ControlNo,15)= max(0.1,2-Result(ControlNo,10)/60);
            % ����K1
            % K1=(0.1,Vj/Vn)
            Result(ControlNo,13)= Result(ControlNo,11)/Vn;
            if Result(ControlNo,13)>4.2
                Result(ControlNo,13)=0.1;
            end
%             if Result(ControlNo,11)<2*Vn
%                 % ����ͳ����Ϣ��Vj<2*Vn�������㣬����Ϊ0.1
%                 Result(ControlNo,13)= max(0.1,Result(ControlNo,11)/Vn);
%             else
%                 Result(ControlNo,13)= 0.1;
%             end
%             Result(ControlNo,13)= max(0.1,Result(ControlNo,11)/Vn);
            % ����K2
            % detp=abs(p-agc)*dt/time
            % K2=2-detp/detPn
            if Result(ControlNo,7)- Result(ControlNo,9)~=0
                for m= Result(ControlNo,7):scanrate:Result(ControlNo,9)
                    Result(ControlNo,12)= Result(ControlNo,12)+abs(Pall(m)-Result(ControlNo,1))*scanrate;
                end
                Result(ControlNo,12)=Result(ControlNo,12)/(Result(ControlNo,9)-Result(ControlNo,7));
            else
                Result(ControlNo,12)=abs(Result(ControlNo,8)-Result(ControlNo,1));
            end
            Result(ControlNo,14)=max(0.1,2-Result(ControlNo,12)/detPn);
            % ����Kp
            Result(ControlNo,16)=Result(ControlNo,13)*Result(ControlNo,14)*Result(ControlNo,15);
        end
    end
end
% Mall=D*Kp*5.2
aveK1=mean(Result(:,13));
aveK2=mean(Result(:,14));
aveK3=mean(Result(:,15));
aveKp=aveK1*aveK2*aveK3;
% aveKp=aveK1*aveK2*aveK3;
sumD=sum(Result(:,17));
Mall=sumD*(log(aveKp)+1)*5.2;
Mall0=sumD*aveKp*5.2;

RESULT=Result(Result(:,19)>0,:);
AVEK1=mean(RESULT(RESULT(:,13)>0,13));
if AVEK1>2.1
    AVEK1_a=AVEK1-floor(AVEK1*10)/10+2;
else
    AVEK1_a=AVEK1;
end

AVEK2_a1=mean(RESULT(RESULT(:,13)>0,14));
AVEK2_a=AVEK2_a1;

AVEK3_a1=mean(RESULT(RESULT(:,13)>0,15));
if AVEK3_a1>1.7
    AVEK3_a=AVEK3_a1-floor(AVEK3_a1*10)/10+1.6;
else
    AVEK3_a=AVEK3_a1;
end
% aveKp=aveK1*aveK2*aveK3;
AVEKp=AVEK3_a*AVEK2_a*AVEK1_a;
sumD=sum(RESULT(:,17));
MALL=sumD*(log(AVEKp)+1)*5.2;
MALL0=sumD*AVEKp*5.2;
% ���˵���
% if aveK1<1
%     K1kaohe=(1-aveK1)*Pe*2;
% end
% if aveK2<1
%     K2kaohe=(1-aveK2)*Pe*2;
% end
% if aveK1<1
%     K3kaohe=(1-aveK3)*Pe*2;
% end

%% AGCָ��ǿ�ȷ���
ResultAGC=zeros(96,8); % ÿ15���ӿ���һ��
% ResultAGC=[       1               2                3              4           5              6               7           8        9            10]
% ResultAGC=[15min�����ָ�� 15min����Сָ�� 15min��ƽ��ָ��ֵ ʱ����ʼAGC ʱ�ν���AGC ��������������½� ��������ʱ�� �۷����� ָ������ ָ��ƽ������ʱ��]
for i=1:900:86400
    N=(i-1)/900+1;
    ResultAGC(N,1)=max(AGC(i:i+899)); % 15min�����ָ��
    ResultAGC(N,2)=min(AGC(i:i+899)); % 15min����Сָ��
    ResultAGC(N,3)=mean(AGC(i:i+899));% 15min��ƽ��ָ��ֵ
    Record=zeros(10,4);
%   Record=[AGC i0 iend flag]
    Record(1,1)=AGC(i);
    Record(1,2)=i;
    ctl=1;
    for j=i:i+899
        if abs(AGC(j)-Record(ctl,1))>2
            Record(ctl,3)=j-1;
            ctl=ctl+1;
            Record(ctl,1)=AGC(j);
            Record(ctl,2)=j;
        end
    end
    Plus=0;Minus=0;Tplus=0;Tminus=0;
    for j=2:ctl-1
        if Record(j,1)>Record(j-1,1)
            Plus=Plus+(Record(j,1)-Record(j-1,1));
            Tplus=Tplus+(Record(j,3)-Record(j-1,2));
            Record(j,4)=1;
            Minus=0;
            Tminus=0;
        else
            Plus=0;
            Tplus=0;
            Record(j,4)=-1;
            Minus=Minus+(Record(j,1)-Record(j-1,1));
            Tminus=Tminus+(Record(j,3)-Record(j-1,2));
        end
        if Plus>-Minus
            Tm=Tplus;
            Pm=Plus;
        else
            Tm=Tminus;
            Pm=-Minus;
        end
        if Pm>ResultAGC(N,4)
            ResultAGC(N,6)=Pm; % ��������������½�
            ResultAGC(N,7)=Tm; % ����������³���ʱ��
        end
    end
    Turnb=Record(1:(end-1),4).*Record(2:end,4);
    ResultAGC(N,4)=Record(1,1);
    ResultAGC(N,5)=Record(ctl,1);
    ResultAGC(N,8)=sum(Turnb<0); % �۷�����
    ResultAGC(N,9)=ctl;
    ResultAGC(N,10)=mean(Record(1:ctl-1,3)-Record(1:ctl-1,2));
end
No_AGC=size(Result);
No_AGC=No_AGC(1); % AGC����Ч���ڴ���
TurnB=Result(1:(end-1),18).*Result(2:end,18); % �۷�����
No_TurnB_AGC=abs(sum(TurnB<0)); % ��Ч���۷����ڴ���.
Range_AGC=abs(Result(:,1)-Result(:,2)); % AGCÿ�εĵ��ڷ���
Ave_ran_AGC=mean(Range_AGC); % ����ƽ�����ڷ���
Ave_Time=mean(Result(:,9)-Result(:,3)); % AGCָ���ƽ������ʱ��
day_agcresult=[No_AGC No_TurnB_AGC Ave_ran_AGC Ave_Time];
%% ���ܵ�վ�ĵ���ǿ�ȷ���
Pedg=7;
Pbat=Pall-P;
Plus_Pdg=sum(Pbat(Pbat>0));  % �����ۻ��ŵ繦��,MW
Minus_Pdg=sum(Pbat(Pbat<0));  % �����ۻ���繦��
PlusE_Pdg=Plus_Pdg/3600;  % �����ۻ��ŵ����,MWh
MinusE_Pdg=Minus_Pdg/3600;  % �����ۻ��ŵ����
Eqv_Cycplus=PlusE_Pdg/(Pedg); % ��Чѭ������(�ſգ�
Eqv_Cycminus=MinusE_Pdg/(Pedg); % ��Чѭ��������������
Initial_SOC=20;
Bat=zeros(len,3);
% Bat = [       1              2                 3]
% Bat = [ ���ܳ�Ź���    ÿ�γ�ű���     ÿ�γ�ŵ���
BatResult=zeros(10,8); % ��صļ�����
% BatResult=[    1           2                  3                    4                  5               6          7            8];
% BatResult=[��¼AGC  ������ڹ����ܺ�  ������ڹ����ܺ�     ��Ч��2C�ŵ�ʱ��    ��Ч��2C���ʱ��   �ŵ����  �ۼƷŵ����  ʣ��SOC];
% ÿ��AGCָ����ʱ�Ĺ���
Bat(:,1)=Pbat;
Bat(:,2)=Bat(:,1)/Pedg;
Bat(:,3)=Bat(:,1)/3600;% �ŵ��������λMWh
CtrlNo=1;
BatResult(CtrlNo,1)=AGC(1);
BatResult(CtrlNo,8)=Initial_SOC;
for i=1:scanrate:86400
    if abs(AGC(i)-BatResult(CtrlNo,1))>=2 %deadzone3*Pe %Pe*0.01
        % ��AGC��ǰֵ>��¼AGCֵ+2(����Pe*0.01)������AGC�����˶��������ܳ�����һ���µ�AGC
        % ����Ҫ������һ��AGC�µĴ�������
        BatResult(CtrlNo,4)=BatResult(CtrlNo,2)/(2*Pedg);% ��λs
        BatResult(CtrlNo,5)=BatResult(CtrlNo,3)/(2*Pedg);% ��λs
        BatResult(CtrlNo,6)=BatResult(CtrlNo,6)/Pedg*100;% ��λ%
        if CtrlNo == 1
            BatResult(CtrlNo,7)=BatResult(CtrlNo,6);% ��λ%
            BatResult(CtrlNo,8)=BatResult(CtrlNo,8)-BatResult(CtrlNo,6);
        else
            BatResult(CtrlNo,7)=BatResult(CtrlNo-1,7)+BatResult(CtrlNo,6);
            BatResult(CtrlNo,8)=BatResult(CtrlNo-1,8)-BatResult(CtrlNo,6);
        end
        CtrlNo=CtrlNo+1;
        BatResult(CtrlNo,1)=AGC(i);
    else
        % ���AGCָ������仯��������ۼƴ��ܵĽ��
        if Bat(i,1)>0
            BatResult(CtrlNo,2)=BatResult(CtrlNo,2)+Bat(i,1)*scanrate;%��λMW����ʱ��scanrate�����������5�θù���
        end
        if Bat(i,1)<0
            BatResult(CtrlNo,3)=BatResult(CtrlNo,3)+Bat(i,1)*scanrate;
        end
        BatResult(CtrlNo,6)=BatResult(CtrlNo,6)+sum(Bat(i:i+4,1))/3600;%��λMWh
    end
end
Old=[aveK1,aveK2,aveK3,aveKp,sumD,Mall,Mall0,Eqv_Cycplus,Eqv_Cycminus];
New=[AVEK1_a,AVEK2_a,AVEK3_a,AVEKp,sumD,MALL,MALL0,Eqv_Cycplus,Eqv_Cycminus];