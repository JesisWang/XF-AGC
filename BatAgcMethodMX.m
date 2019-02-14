function [BatPower,status] = BatAgcMethodMX(AgcLimit,GenPower,Pall,BatSoc,Verbose)
% ������ּ��ʵ�ִ���AGC�㷨��������AGC������ֵ�ͻ��鹦������财���ܳ����������
% ���룺
%	AgcLimit��   ��������ʾAGC������ֵ���ɵ��ȸ�������λ��MW��
%	GenPower��   ��������ʾ�������ʵ�⹦��ֵ����λ��MW��
%   BatSoc��     ��������ؿ���������0��100����λ��%��
%   Verbose��    ��������ʾ�澯��ʾ�ȼ���0-9��9��ʾ���澯��0����ʾ�澯��
% �����
%	BatPower��	��������ʾ�����ܹ��ʣ���λ��MW���ŵ�Ϊ����
%	status��     ��������ʾ�����ķ���״̬��>=0��ʾ������<0��ʾ�쳣��
% �汾������޸��� 2017-08-17
% 2017-08-17 HB
% 1. �޸�ԭ��һ���˲������Ӵ���б��������ƣ����ܵĻ����˳�����ԭ��һ���˲���
% 2. SOC��50%���ң�ȫ��ӦDetP������K2ָ��
% 2016-09-13 HB
% 1. ��������������������������Ƴ���׫дע�͡�

    % ȫ�ֱ�������
    global Tline;   % �����ã����ڼ���ʱ�䡣
    global AgcStart;    % ��ʼʱ�䡣
    global GenPower0;   % ������ʼ������
    global LastAgc;     % ��������ʾ��һ��AGC������ֵ���ɵ��ȸ�������λMW��
    global LastPbat;	% ��������ʾ��һ�δ���ָ��ֵ�����㷨��ã���λMW��
    global Para;        % ������1��14��t01\t12\Pmax\Pmin\Phold\SocTarget\SocZone1\SocZone2\SocMax\SocMin\Erate\Prgen\Vgen\DeadZone���㷨������
    global LastAgcLimit;
    global SOC0;
    global Pall0;
    global Ptarget;
    global SocFlag;     % �ѿ�ʼSOCά��
    global FlagAGC;     % �������ﵽAGCָ��
    global VgP0;
    global Vg;
    
    status = -1;    % ��ɳ�ʼ����״̬Ϊ-1
    %BatPower = 0;
    
    % ������
    if (isempty(Verbose)||isnan(Verbose));
        Verbose = 0;
    end;
    if (isempty(AgcLimit)||isempty(GenPower)||isempty(BatSoc)||isempty(Para)) || ...
       (isnan(AgcLimit)||isnan(GenPower)||isnan(BatSoc)||(sum(isnan(Para))>0)); 
        % ������ڿ������NAN��״̬Ϊ-2
        status = -2;
        WarnLevel = 1;
        if WarnLevel < Verbose;
            fprintf('Input data can not be empty or NaN!');
        end;
        return;
    elseif (length(Para) ~= 14);
        % �������ݸ�ʽ������Ҫ��״̬Ϊ-3
        status = -3;
        WarnLevel = 1;
        if WarnLevel < Verbose;
            fprintf('Para data is not correct format!');
        end;
        return;
    elseif AgcLimit <= 0;
        % AGC��ֵС�ڵ���0��״̬Ϊ0
        status = 0;
        WarnLevel = 3;
        if WarnLevel < Verbose;
            fprintf('AGC limit is 0!');
        end;
        return;
    end;
    
    Erate = Para(11);
    Prgen = Para(12);
    Vgen = Para(13);   % MW/min
    Cdead = 2;%1/100;
    ParaVbat = 1.5/100*Prgen * 1.8/60; 
    % AGC�㷨
    if (AgcLimit > LastAgc+Cdead) ||  (AgcLimit < LastAgc-Cdead)    % AGCָ��仯
        FlagAGC = 0;
        SocFlag = 0;
        AgcStart = Tline;
        GenPower0 = GenPower;
        LastAgcLimit = LastAgc;
        LastAgc = AgcLimit;
        SOC0 = BatSoc;
        Pall0 = Pall;
        Ptarget = Pall;
        VgP0 = GenPower;
    end
    
    DetP = AgcLimit - GenPower;     % �������������
    DetT = Tline-AgcStart;
    if (DetT<=5)                  % AGCָ���ʼt01�ڣ��޹����������֤K3ָ��
        if (AgcLimit<Pall0)
            Vg = -2;
            BatPower = 0;
        else
            Vg = 2;
            BatPower = 0;
        end
        status = 1;
    else
        if (DetT==6)            
            if (AgcLimit<GenPower)
                Ptarget = Pall0-Cdead;
            else
                Ptarget = Pall0+Cdead;
            end
        elseif (mod(DetT,60)==0)
            Vg = GenPower-VgP0;
            VgP0 = GenPower;
        end
        
        if (BatSoc<=Para(10))                                % SOC������ά����SocMin
            Ptarget = Pall;
            BatPower = min(DetP,-Para(5));
            SocFlag = 1;
        elseif (BatSoc>Para(9))                             % SOC������ά����SocMax     
            Ptarget = Pall;
            BatPower = max(DetP,Para(5));
            SocFlag = 1;
        elseif (BatSoc>Para(10)+Para(8))&&(BatSoc<=Para(9)-Para(8))   % SOC�ڷ�Χ�ڣ��ɽ���AGC���ڣ�SocMin+SocDead��SocMax-SocDead
            SocFlag = 0;
            if (abs(DetP)>Cdead)          % ����AGC���ڹ��̣�����K1\K2
                if (FlagAGC>0)  % �������������
                    if (BatSoc>(Para(6)+Para(8)))
                        BatPower = max(DetP,Para(5));
                    elseif (BatSoc<(Para(6)-Para(8)))
                        BatPower = min(DetP,-Para(5));
                    else
                        BatPower = DetP;
                    end
                elseif (DetT>Para(2))   % ��ʱ�䲹��������������
                    if (AgcLimit>GenPower0)
                        if Vg<0
                            Ptarget = 0.95*Ptarget+0.05*GenPower;
                        elseif Vg<Vgen/2
                            Ptarget = 0.98*Ptarget+0.02*GenPower;
                        end
                        BatPower = min(DetP,Ptarget-GenPower);
                        BatPower = max(0,BatPower);
                    else
                        if Vg>0
                            Ptarget = 0.95*Ptarget+0.05*GenPower;
                        elseif Vg>-Vgen/2
                            Ptarget = 0.98*Ptarget+0.02*GenPower;
                        end
                        BatPower = max(DetP,Ptarget-GenPower);
                        BatPower = min(0,BatPower);
                    end
                else                    % ��ʱ��������������
                    if (AgcLimit<GenPower0)
                        if (((70-BatSoc)*3600*Erate/100)>(DetP/Vgen*60*Para(4)-0.5*Para(4)/Vgen*60*Para(4)))
                            Ptarget = AgcLimit;
                        end
                        BatPower = max(DetP,Ptarget-GenPower);
                        BatPower = min(0,BatPower);
                    else
                        if (((BatSoc-30)*3600*Erate/100)>(DetP/Vgen*60*Para(3)-0.5*Para(3)/Vgen*60*Para(3)))
                            Ptarget = AgcLimit;
                        end
                        BatPower = min(DetP,Ptarget-GenPower);
                        BatPower = max(0,BatPower);
                    end
                end
            else                                % ���������ϣ�ά��SOC
                FlagAGC = 1;
                if (BatSoc>(Para(6)+Para(8)))
                    BatPower = max(DetP,Para(5));
                elseif (BatSoc<(Para(6)-Para(8)))
                    BatPower = min(DetP,-Para(5));
                else
                    BatPower = DetP;
                end
            end
        else     % ��������Pb����ֱ��SOC�ص��ɽ���AGC�ķ�Χ
            if (abs(DetP)<=Cdead)
                Ptarget = Pall;
                FlagAGC = 1;
                if (BatSoc>Para(6))
                    BatPower = max(DetP,Para(5));
                else
                    BatPower = min(DetP,-Para(5));
                end
            else
                if (FlagAGC>0)
                    Ptarget = Pall;
                    if (BatSoc>Para(6))
                        BatPower = max(DetP,Para(5));
                    else
                        BatPower = min(DetP,-Para(5));
                    end
                elseif(SocFlag==1) % ֮ǰ�ڽ���SOCά�����򱣳�P���򲻱䣬��Ӧͬ��AGC����
                    Ptarget = Pall;
                    if LastPbat>=0
                        BatPower = max(DetP,Para(5));
                    else
                        BatPower = min(DetP,-Para(5));
                    end
                else            % ֮ǰ�ڽ���AGC���ڣ�������𵴣����ܻ�����Ϊ0��������ﵽAGCָ������SOCά��
                    if (Ptarget-GenPower>0)
                        Ptarget = 0.95*Ptarget+0.05*GenPower;
                        BatPower = max(0,Ptarget-GenPower);
                    else
                        Ptarget = 0.95*Ptarget+0.05*GenPower;
                        BatPower = min(0,Ptarget-GenPower);
                    end
                    if (BatSoc>Para(6)+Para(7))
                        BatPower = max(DetP,BatPower);
                    elseif (BatSoc<Para(6)-Para(7))
                        BatPower = min(DetP,BatPower);
                    end
                end
            end
        end

    end
    if (BatPower>Para(3))
        BatPower = Para(3);
    elseif  (BatPower<Para(4))
        BatPower = Para(4);
    end

    Tbat = max(0,(DetT-5));
    if (AgcLimit>Pall0) % ������
        if (BatPower+GenPower-Pall0)>(ParaVbat*Tbat)
            BatPower = Pall0-GenPower+(ParaVbat*Tbat);
        end
    else                % ������
        if (BatPower+GenPower-Pall0)<-(ParaVbat*Tbat)
            BatPower = Pall0-GenPower-(ParaVbat*Tbat);
        end
    end
%     if abs(BatPower-LastPbat)<0.2
%         BatPower = LastPbat;
%     else
end

