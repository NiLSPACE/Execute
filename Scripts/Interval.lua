local world = cRoot:Get():GetDefaultWorld()local i = 1;local function Exec()    LOG(i);    i = i + 1    world:ScheduleTask(100, Exec)endExec()