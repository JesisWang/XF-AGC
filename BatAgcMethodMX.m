function [BatPower,status] = BatAgcMethodMX(AgcLimit,GenPower,Pall,BatSoc,Verbose)
% 本函数旨在实现储能AGC算法，即根据AGC功率限值和机组功率求解需储能总出力并输出。
% 输入：
%	AgcLimit：   标量，表示AGC功率限值，由调度给定，单位：MW。
%	GenPower：   标量，表示发电机组实测功率值，单位：MW。
%   BatSoc：     标量，电池可用容量，0～100，单位：%。
%   Verbose：    标量，表示告警显示等级，0-9，9显示最多告警，0不显示告警。
% 输出：
%	BatPower：	标量，表示储能总功率，单位：MW，放电为正。
%	status：     标量，表示函数的返回状态，>=0表示正常，<0表示异常。
% 版本：最后修改于 2017-08-17
% 2017-08-17 HB
% 1. 修改原有一阶滤波，增加储能斜率输出控制（储能的缓慢退出保留原有一阶滤波）
% 2. SOC在50%左右，全相应DetP，提升K2指标
% 2016-09-13 HB
% 1. 建立函数，定义输入输出，编制程序，撰写注释。

    % 全局变量定义
    global Tline;   % 测试用，用于计算时间。
    global AgcStart;    % 起始时间。
    global GenPower0;   % 机组起始出力。
    global LastAgc;     % 标量，表示上一次AGC功率限值，由调度给定，单位MW。
    global LastPbat;	% 标量，表示上一次储能指令值，由算法求得，单位MW。
    global Para;        % 向量，1×14，t01\t12\Pmax\Pmin\Phold\SocTarget\SocZone1\SocZone2\SocMax\SocMin\Erate\Prgen\Vgen\DeadZone，算法参数。
    global LastAgcLimit;
    global SOC0;
    global Pall0;
    global Ptarget;
    global SocFlag;     % 已开始SOC维护
    global FlagAGC;     % 机组曾达到AGC指令
    global VgP0;
    global Vg;
    
    status = -1;    % 完成初始化，状态为-1
    %BatPower = 0;
    
    % 输入检查
    if (isempty(Verbose)||isnan(Verbose));
        Verbose = 0;
    end;
    if (isempty(AgcLimit)||isempty(GenPower)||isempty(BatSoc)||isempty(Para)) || ...
       (isnan(AgcLimit)||isnan(GenPower)||isnan(BatSoc)||(sum(isnan(Para))>0)); 
        % 输入存在空数组或NAN，状态为-2
        status = -2;
        WarnLevel = 1;
        if WarnLevel < Verbose;
            fprintf('Input data can not be empty or NaN!');
        end;
        return;
    elseif (length(Para) ~= 14);
        % 参数数据格式不符合要求，状态为-3
        status = -3;
        WarnLevel = 1;
        if WarnLevel < Verbose;
            fprintf('Para data is not correct format!');
        end;
        return;
    elseif AgcLimit <= 0;
        % AGC限值小于等于0，状态为0
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
    % AGC算法
    if (AgcLimit > LastAgc+Cdead) ||  (AgcLimit < LastAgc-Cdead)    % AGC指令变化
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
    
    DetP = AgcLimit - GenPower;     % 计算待调整功率
    DetT = Tline-AgcStart;
    if (DetT<=5)                  % AGC指令初始t01内，限功率输出，保证K3指标
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
        
        if (BatSoc<=Para(10))                                % SOC超下限维护，SocMin
            Ptarget = Pall;
            BatPower = min(DetP,-Para(5));
            SocFlag = 1;
        elseif (BatSoc>Para(9))                             % SOC超上限维护，SocMax     
            Ptarget = Pall;
            BatPower = max(DetP,Para(5));
            SocFlag = 1;
        elseif (BatSoc>Para(10)+Para(8))&&(BatSoc<=Para(9)-Para(8))   % SOC在范围内，可进行AGC调节，SocMin+SocDead～SocMax-SocDead
            SocFlag = 0;
            if (abs(DetP)>Cdead)          % 机组AGC调节过程，提升K1\K2
                if (FlagAGC>0)  % 机组曾调节完毕
                    if (BatSoc>(Para(6)+Para(8)))
                        BatPower = max(DetP,Para(5));
                    elseif (BatSoc<(Para(6)-Para(8)))
                        BatPower = min(DetP,-Para(5));
                    else
                        BatPower = DetP;
                    end
                elseif (DetT>Para(2))   % 长时间补偿，检查机组速率
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
                else                    % 短时补偿，核算容量
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
            else                                % 机组调节完毕，维护SOC
                FlagAGC = 1;
                if (BatSoc>(Para(6)+Para(8)))
                    BatPower = max(DetP,Para(5));
                elseif (BatSoc<(Para(6)-Para(8)))
                    BatPower = min(DetP,-Para(5));
                else
                    BatPower = DetP;
                end
            end
        else     % 死区保持Pb方向，直至SOC回到可进行AGC的范围
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
                elseif(SocFlag==1) % 之前在进行SOC维护，则保持P方向不变，响应同向AGC需求
                    Ptarget = Pall;
                    if LastPbat>=0
                        BatPower = max(DetP,Para(5));
                    else
                        BatPower = min(DetP,-Para(5));
                    end
                else            % 之前在进行AGC调节，需避免震荡，储能缓慢降为0，待机组达到AGC指令后进行SOC维护
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
    if (AgcLimit>Pall0) % 升出力
        if (BatPower+GenPower-Pall0)>(ParaVbat*Tbat)
            BatPower = Pall0-GenPower+(ParaVbat*Tbat);
        end
    else                % 降出力
        if (BatPower+GenPower-Pall0)<-(ParaVbat*Tbat)
            BatPower = Pall0-GenPower-(ParaVbat*Tbat);
        end
    end
%     if abs(BatPower-LastPbat)<0.2
%         BatPower = LastPbat;
%     else
end

