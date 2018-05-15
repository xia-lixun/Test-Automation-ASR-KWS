function param = parse_task_specification(ini_file, param)

    config = ini2struct(ini_file);
    tasks = fieldnames(config);
    
    for i = 1:length(tasks)
        
        param.task(i).topic = tasks{i};
        param.task(i).room = ini_decomment(config.(tasks{i}).room);
        param.task(i).testtype = ini_decomment(config.(tasks{i}).testtype);
        param.task(i).dutorient = str2double(ini_decomment(config.(tasks{i}).dutorientation));
        report = ini_decomment(config.(tasks{i}).report);
        param.task(i).report = report(2:end-1);
        
        mouth50cm = ini_decomment(config.(tasks{i}).mouth50cm);
        param.task(i).mouth50cm = mouth50cm(2:end-1);
        mouth1m = ini_decomment(config.(tasks{i}).mouth1m);
        param.task(i).mouth100cm = mouth1m(2:end-1);
        mouth3m = ini_decomment(config.(tasks{i}).mouth3m);
        param.task(i).mouth300cm = mouth3m(2:end-1);
        mouth5m = ini_decomment(config.(tasks{i}).mouth5m);
        param.task(i).mouth500cm = mouth5m(2:end-1);
        param.task(i).mouthlevel = str2double(ini_decomment(config.(tasks{i}).mouthlevel));
        
        noise = ini_decomment(config.(tasks{i}).noise);
        param.task(i).noise = noise(2:end-1);
        param.task(i).noiselevel = str2double(ini_decomment(config.(tasks{i}).noiselevel));
        
        echo = ini_decomment(config.(tasks{i}).echo);
        param.task(i).echo = echo(2:end-1);
        param.task(i).echolevel = str2double(ini_decomment(config.(tasks{i}).echolevel));
        
        
        stamic = ini_decomment(config.(tasks{i}).refmic);
        param.task(i).standardmic = stamic(2:end-1);
        
        micin = ini_decomment(config.(tasks{i}).micin);
        param.task(i).micin = micin(2:end-1);
        micref = ini_decomment(config.(tasks{i}).micref);
        param.task(i).micref = micref(2:end-1);
        micinput = ini_decomment(config.(tasks{i}).micinput);
        param.task(i).micinput = micinput(2:end-1);
        dcblock = ini_decomment(config.(tasks{i}).dcblock);
        param.task(i).dcblock = dcblock(2:end-1);
        aec = ini_decomment(config.(tasks{i}).aec);
        param.task(i).aec = aec(2:end-1);
        fixedbeamformer = ini_decomment(config.(tasks{i}).fixedbeamformer);
        param.task(i).fixedbeamformer = fixedbeamformer(2:end-1);
        globaleq = ini_decomment(config.(tasks{i}).globaleq);
        param.task(i).globaleq = globaleq(2:end-1);
        spectralbeamsteering = ini_decomment(config.(tasks{i}).spectralbeamsteering);
        param.task(i).spectralbeamsteering = spectralbeamsteering(2:end-1);
        adaptivebeamformer = ini_decomment(config.(tasks{i}).adaptivebeamformer);
        param.task(i).adaptivebeamformer = adaptivebeamformer(2:end-1);
        noisereduction = ini_decomment(config.(tasks{i}).noisereduction);
        param.task(i).noisereduction = noisereduction(2:end-1);
        asrleveler = ini_decomment(config.(tasks{i}).asrleveler);
        param.task(i).asrleveler = asrleveler(2:end-1);
        asrlimiter = ini_decomment(config.(tasks{i}).asrlimiter);
        param.task(i).asrlimiter = asrlimiter(2:end-1);
        callleveler = ini_decomment(config.(tasks{i}).callleveler);
        param.task(i).callleveler = callleveler(2:end-1);
        expander = ini_decomment(config.(tasks{i}).expander);
        param.task(i).expander = expander(2:end-1);
        calleq = ini_decomment(config.(tasks{i}).calleq);
        param.task(i).calleq = calleq(2:end-1);
        calllimiter = ini_decomment(config.(tasks{i}).calllimiter);
        param.task(i).calllimiter = calllimiter(2:end-1);
        micout = ini_decomment(config.(tasks{i}).micout);
        param.task(i).micout = micout(2:end-1);
        
end