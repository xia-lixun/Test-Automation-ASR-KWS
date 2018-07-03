





function ui()
    w = Tk.Toplevel("Automatic Audio Test Tool - CoC Suzhou", 1000, 900)
    Tk.pack_stop_propagate(w)
   

    m = Tk.Menu(w)
    fmenu = Tk.menu_add(m, "File")
    omenu = Tk.menu_add(m, "Options")
    hmenu = Tk.menu_add(m, "Help")


    conf = Dict{String, Any}()
    function loadconf(path)
        conf = JSON.parsefile(Tk.GetOpenFile())
    end
    function saveconf(path)
        open(Tk.GetSaveFile(), "w") do fid
            write(fid, JSON.json(conf))
        end
    end

    Tk.menu_add(fmenu, "Open File...", loadconf)
    Tk.menu_add(fmenu, "Save As...", saveconf)
    Tk.menu_add(fmenu, Tk.Separator(w))
    Tk.menu_add(fmenu, "Close Tool", (path)->Tk.destroy(w))
    

    cb_ut = Tk.Checkbutton(w, "Use Turntable")
    Tk.set_value(cb_ut, true)
    Tk.menu_add(omenu, cb_ut)

    cb_cdis = Tk.Checkbutton(w, "Capture DUT Internal Signals")
    Tk.set_value(cb_cdis, true)
    Tk.menu_add(omenu, cb_cdis)
    
    cb_dcdc = Tk.Checkbutton(w, "DUT Clock Drift Compensation")
    Tk.set_value(cb_dcdc, true)
    Tk.menu_add(omenu, cb_dcdc)
    Tk.menu_add(omenu, Tk.Separator(w))

    # rb = Radio(w, ["option 1", "option 2"])
    # set_value(rb, "option 1")
    # menu_add(omenu, rb)
    
    Tk.menu_add(hmenu, "Help...", (path)->println("open help file"))
    Tk.menu_add(hmenu, Tk.Separator(w))
    Tk.menu_add(hmenu, "About", (path)->Tk.Messagebox(w, title="Author", message="Xia Lixun"))



    #
    ##
    nb = Tk.Notebook(w)
    Tk.pack(nb, expand=true, fill="both")


    # task tabs
    tasktab = Dict{String, Tk.Tk_Frame}()

    lfa1 = Dict{String, Tk.Tk_Labelframe}()
    t_room = Dict{String, Tk.Tk_Entry}()
    t_type = Dict{String, Tk.Tk_Entry}()
    t_orient = Dict{String, Tk.Tk_Entry}()
    
    lfa2 = Dict{String, Tk.Tk_Labelframe}()
    t_mth_src = Dict{String, Tk.Tk_Entry}()
    b_mth_src = Dict{String, Tk.Tk_Button}()
    t_mth_port = Dict{String, Tk.Tk_Entry}()
    t_mth_lev = Dict{String, Tk.Tk_Entry}()
    t_mth_cal0 = Dict{String, Tk.Tk_Entry}()
    t_mth_cal1 = Dict{String, Tk.Tk_Entry}()
    t_mth_meas = Dict{String, Tk.Tk_Entry}()

    lfa3 = Dict{String, Tk.Tk_Labelframe}()
    t_nos_src = Dict{String, Tk.Tk_Entry}()
    b_nos_src = Dict{String, Tk.Tk_Button}()
    t_nos_lev = Dict{String, Tk.Tk_Entry}()
    t_nos_cal0 = Dict{String, Tk.Tk_Entry}()
    t_nos_cal1 = Dict{String, Tk.Tk_Entry}()
    t_nos_meas = Dict{String, Tk.Tk_Entry}()

    lfa4 = Dict{String, Tk.Tk_Labelframe}()
    t_eco_src = Dict{String, Tk.Tk_Entry}()
    b_eco_src = Dict{String, Tk.Tk_Button}()
    t_eco_lev = Dict{String, Tk.Tk_Entry}()
    t_eco_cal0 = Dict{String, Tk.Tk_Entry}()
    t_eco_cal1 = Dict{String, Tk.Tk_Entry}()
    t_eco_meas = Dict{String, Tk.Tk_Entry}()


    function addconf(title)
        stubmouth = Dict("Source"=>"", "Port"=>7, "Level(dBA)"=>65, "Calibration Start(sec)"=>65.5, "Calibration Stop(sec)"=>66.611, "Measure Port"=>9)
        stubnoise = Dict("Source"=>"", "Level(dBA)"=>58, "Calibration Start(sec)"=>60.0, "Calibration Stop(sec)"=>120.0, "Measure Port"=>9)
        stubecho = Dict("Source"=>"", "Level(dBA)"=>87, "Calibration Start(sec)"=>60.0, "Calibration Stop(sec)"=>120.0, "Measure Port"=>9)
        stub = Dict("Topic"=>title, 
                    "Room"=>"", 
                    "Type"=>"", 
                    "Orientation(deg)"=>0.0,
                    "Mouth" => stubmouth,
                    "Noise" => stubnoise,
                    "Echo" => stubecho)
        push!(conf["Task"], stub)
    end

    function addelement(frame, title)
        ##
        lfa1[title] = Tk.Labelframe(frame, "General Information")
        Tk.pack(lfa1[title], expand=true, fill="both")

        t_room[title] = Tk.Entry(lfa1[title], width=95)
        t_type[title] = Tk.Entry(lfa1[title], width=95)
        t_orient[title] = Tk.Entry(lfa1[title], width=95)
        Tk.formlayout(t_room[title], "Room ")
        Tk.formlayout(t_type[title], "Type ")
        Tk.formlayout(t_orient[title], "DUT Orientation ")

        ##
        lfa2[title] = Tk.Labelframe(frame, "Mouth")
        Tk.pack(lfa2[title], expand=true, fill="both")

        t_mth_src[title] = Tk.Entry(lfa2[title], width=95)
        b_mth_src[title] = Tk.Button(lfa2[title], "Browse...")
        t_mth_port[title] = Tk.Entry(lfa2[title], width=95)
        t_mth_lev[title] = Tk.Entry(lfa2[title], width=95)
        t_mth_cal0[title] = Tk.Entry(lfa2[title], width=95)
        t_mth_cal1[title] = Tk.Entry(lfa2[title], width=95)
        t_mth_meas[title] = Tk.Entry(lfa2[title], width=95)

        Tk.formlayout(t_mth_src[title], "Source ")
        Tk.formlayout(b_mth_src[title], nothing)
        Tk.formlayout(t_mth_port[title], "Play Port ")
        Tk.formlayout(t_mth_lev[title], "Level (dBA) ")
        Tk.formlayout(t_mth_cal0[title], "Calibration Start (sec) ")
        Tk.formlayout(t_mth_cal1[title], "Calibration Stop (sec) ")
        Tk.formlayout(t_mth_meas[title], "Meas. Mic Port ")

        function callback_update_mthsrc(path)
            Tk.set_value(t_mth_src[title], Tk.GetOpenFile())
        end
        Tk.bind(b_mth_src[title], "command", callback_update_mthsrc)


        ##
        lfa3[title] = Tk.Labelframe(frame, "Noise")
        Tk.pack(lfa3[title], expand=true, fill="both")

        t_nos_src[title] = Tk.Entry(lfa3[title], width=95)
        b_nos_src[title] = Tk.Button(lfa3[title], "Browse...")
        t_nos_lev[title] = Tk.Entry(lfa3[title], width=95)
        t_nos_cal0[title] = Tk.Entry(lfa3[title], width=95)
        t_nos_cal1[title] = Tk.Entry(lfa3[title], width=95)
        t_nos_meas[title] = Tk.Entry(lfa3[title], width=95)

        Tk.formlayout(t_nos_src[title], "Source ")
        Tk.formlayout(b_nos_src[title], nothing)
        Tk.formlayout(t_nos_lev[title], "Level (dBA) ")
        Tk.formlayout(t_nos_cal0[title], "Calibration Start (sec) ")
        Tk.formlayout(t_nos_cal1[title], "Calibration Stop (sec) ")
        Tk.formlayout(t_nos_meas[title], "Meas. Mic Port ")

        function callback_update_nossrc(path)
            Tk.set_value(t_nos_src[title], Tk.GetOpenFile())
        end
        Tk.bind(b_nos_src[title], "command", callback_update_nossrc) 
        

        ##
        lfa4[title] = Tk.Labelframe(frame, "Echo")
        Tk.pack(lfa4[title], expand=true, fill="both")

        t_eco_src[title] = Tk.Entry(lfa4[title], width=95)
        b_eco_src[title] = Tk.Button(lfa4[title], "Browse...")
        t_eco_lev[title] = Tk.Entry(lfa4[title], width=95)
        t_eco_cal0[title] = Tk.Entry(lfa4[title], width=95)
        t_eco_cal1[title] = Tk.Entry(lfa4[title], width=95)
        t_eco_meas[title] = Tk.Entry(lfa4[title], width=95)

        Tk.formlayout(t_eco_src[title], "Source ")
        Tk.formlayout(b_eco_src[title], nothing)
        Tk.formlayout(t_eco_lev[title], "Level (dBA) ")
        Tk.formlayout(t_eco_cal0[title], "Calibration Start (sec) ")
        Tk.formlayout(t_eco_cal1[title], "Calibration Stop (sec) ")
        Tk.formlayout(t_eco_meas[title], "Meas. Mic Port ")

        function callback_update_ecosrc(path)
            Tk.set_value(t_eco_src[title], Tk.GetOpenFile())
        end
        Tk.bind(b_eco_src[title], "command", callback_update_ecosrc)         
    end

    function element_setvalue(task, title)
        if haskey(task, "Room")
            Tk.set_value(t_room[title], task["Room"])
        else
            Tk.set_value(t_room[title], "")
        end
        if haskey(task, "Type")
            Tk.set_value(t_type[title], task["Type"])
        else
            Tk.set_value(t_type[title], "")
        end
        if haskey(task, "Orientation(deg)")
            Tk.set_value(t_orient[title], string(task["Orientation(deg)"]))
        else
            Tk.set_value(t_orient[title], "")
        end
        if haskey(task, "Mouth")
            Tk.set_value(t_mth_src[title], task["Mouth"]["Source"])
            Tk.set_value(t_mth_port[title], string(task["Mouth"]["Port"]))
            Tk.set_value(t_mth_lev[title], string(task["Mouth"]["Level(dBA)"]))
            Tk.set_value(t_mth_cal0[title], string(task["Mouth"]["Calibration Start(sec)"]))
            Tk.set_value(t_mth_cal1[title], string(task["Mouth"]["Calibration Stop(sec)"]))
            Tk.set_value(t_mth_meas[title], string(task["Mouth"]["Measure Port"]))
        else
            Tk.set_value(t_mth_src[title], "")
            Tk.set_value(t_mth_port[title], "")
            Tk.set_value(t_mth_lev[title], "")
            Tk.set_value(t_mth_cal0[title], "")
            Tk.set_value(t_mth_cal1[title], "")
            Tk.set_value(t_mth_meas[title], "")
        end
        if haskey(task, "Noise")
            Tk.set_value(t_nos_src[title], task["Noise"]["Source"])
            Tk.set_value(t_nos_lev[title], string(task["Noise"]["Level(dBA)"]))
            Tk.set_value(t_nos_cal0[title], string(task["Noise"]["Calibration Start(sec)"]))
            Tk.set_value(t_nos_cal1[title], string(task["Noise"]["Calibration Stop(sec)"]))
            Tk.set_value(t_nos_meas[title], string(task["Noise"]["Measure Port"]))
        else
            Tk.set_value(t_nos_src[title], "")
            Tk.set_value(t_nos_lev[title], "")
            Tk.set_value(t_nos_cal0[title], "")
            Tk.set_value(t_nos_cal1[title], "")
            Tk.set_value(t_nos_meas[title], "")
        end
        if haskey(task, "Echo")
            Tk.set_value(t_eco_src[title], task["Echo"]["Source"])
            Tk.set_value(t_eco_lev[title], string(task["Echo"]["Level(dBA)"]))
            Tk.set_value(t_eco_cal0[title], string(task["Echo"]["Calibration Start(sec)"]))
            Tk.set_value(t_eco_cal1[title], string(task["Echo"]["Calibration Stop(sec)"]))
            Tk.set_value(t_eco_meas[title], string(task["Echo"]["Measure Port"]))
        else
            Tk.set_value(t_eco_src[title], "")
            Tk.set_value(t_eco_lev[title], "")
            Tk.set_value(t_eco_cal0[title], "")
            Tk.set_value(t_eco_cal1[title], "")
            Tk.set_value(t_eco_meas[title], "")
        end
    end

    function element_getvalue(task, title)
        
        task["Room"] = Tk.get_value(t_room[title])
        task["Type"] = Tk.get_value(t_type[title])
        task["Orientation(deg)"] = parse(Float64, Tk.get_value(t_orient[title]))

        task["Mouth"]["Source"] = Tk.get_value(t_mth_src[title])
        task["Mouth"]["Port"] = parse(Int64, Tk.get_value(t_mth_port[title]))
        task["Mouth"]["Level(dBA)"] = parse(Float64, Tk.get_value(t_mth_lev[title]))
        task["Mouth"]["Calibration Start(sec)"] = parse(Float64, Tk.get_value(t_mth_cal0[title]))
        task["Mouth"]["Calibration Stop(sec)"] = parse(Float64, Tk.get_value(t_mth_cal1[title]))
        task["Mouth"]["Measure Port"] = parse(Int64, Tk.get_value(t_mth_meas[title]))

        task["Noise"]["Source"] = Tk.get_value(t_nos_src[title])
        task["Noise"]["Level(dBA)"] = parse(Float64, Tk.get_value(t_nos_lev[title]))
        task["Noise"]["Calibration Start(sec)"] = parse(Float64, Tk.get_value(t_nos_cal0[title]))
        task["Noise"]["Calibration Stop(sec)"] = parse(Float64, Tk.get_value(t_nos_cal1[title]))
        task["Noise"]["Measure Port"] = parse(Int64, Tk.get_value(t_nos_meas[title]))

        task["Echo"]["Source"] = Tk.get_value(t_eco_src[title])
        task["Echo"]["Level(dBA)"] = parse(Float64, Tk.get_value(t_eco_lev[title]))
        task["Echo"]["Calibration Start(sec)"] = parse(Float64, Tk.get_value(t_eco_cal0[title]))
        task["Echo"]["Calibration Stop(sec)"] = parse(Float64, Tk.get_value(t_eco_cal1[title]))
        task["Echo"]["Measure Port"] = parse(Int64, Tk.get_value(t_eco_meas[title]))
    end


    function newtasktab(path)
        id = newtab_entry()
        if haskey(tasktab, id)
            Tk.Messagebox(w, title="Warning", message="Test ID Already Exist! Nothing Added")
        else
            tab = Tk.Frame(nb)
            Tk.page_add(tab, id)
            addelement(tab, id)
            addconf(id)
            tasktab[id] = tab
        end
    end
    Tk.menu_add(omenu, "New Test Item...", newtasktab)



    
    #
    # system config 
    page1 = Tk.Frame(nb)
    Tk.page_add(page1, "System")

    ##
    lf1 = Tk.Labelframe(page1, "Software Information")
    Tk.pack(lf1, expand=true, fill="both")

    e_proj = Tk.Entry(lf1, width=95)
    e_ver = Tk.Entry(lf1, width=95)
    e_rate = Tk.Entry(lf1, width=95)
    e_srv = Tk.Entry(lf1, width=95)

    Tk.formlayout(e_proj, "Project Name ")
    Tk.formlayout(e_ver, "Tool Version ")
    Tk.formlayout(e_rate, "Sample Rate ")
    Tk.formlayout(e_srv, "Score Server IP ")

    
    ##
    lf2 = Tk.Labelframe(page1, "Reference Microphone")
    Tk.pack(lf2, expand=true, fill="both")

    e_rfport = Tk.Entry(lf2, width=95)
    e_rflevcal = Tk.Entry(lf2, width=95)
    b_rflevcal = Tk.Button(lf2, "Browse...")
    Tk.formlayout(e_rfport, "Port Assignment ")
    Tk.formlayout(e_rflevcal, "Level Calibration ")
    Tk.formlayout(b_rflevcal, nothing)

    function callback_update_rfmic(path)
        conf["Reference Mic"]["Level Calibration"] = Tk.ChooseDirectory()
        Tk.set_value(e_rflevcal, conf["Reference Mic"]["Level Calibration"])
    end
    Tk.bind(b_rflevcal, "command", callback_update_rfmic)
    # snd_stat = Label(lf3, "[asio]: no device found")
    # grid(snd_stat,1,1,sticky="news")
    # if !isempty("SoundcardAPI.deviceCnt")
    #     snd_stat[:text] = "returned values" 
    # end


    ##
    lf3 = Tk.Labelframe(page1, "Artificial Mouth")
    Tk.pack(lf3, expand=true, fill="both")

    e_amport = Tk.Entry(lf3, width=95)
    e_amlevcal = Tk.Entry(lf3, width=95)
    b_amlevcal = Tk.Button(lf3, "Browse...")
    Tk.formlayout(e_amport, "Port Assignment ")
    Tk.formlayout(e_amlevcal, "Equalization Filters ")
    Tk.formlayout(b_amlevcal, nothing)

    function callback_update_artmouth(path)
        conf["Artificial Mouth"]["Equalization"] = Tk.GetOpenFile()
        Tk.set_value(e_amlevcal, conf["Artificial Mouth"]["Equalization"])
    end
    Tk.bind(b_amlevcal, "command", callback_update_artmouth)
    
    
    ##
    lf4 = Tk.Labelframe(page1, "Noise Loudspeaker")
    Tk.pack(lf4, expand=true, fill="both")

    e_nlport = Tk.Entry(lf4, width=95)
    e_nllevcal = Tk.Entry(lf4, width=95)
    b_nllevcal = Tk.Button(lf4, "Browse...")
    Tk.formlayout(e_nlport, "Port Assignment ")
    Tk.formlayout(e_nllevcal, "Equalization Filters ")
    Tk.formlayout(b_nllevcal, nothing)

    function callback_update_noiseldspk(path)
        conf["Noise Loudspeaker"]["Equalization"] = Tk.GetOpenFile()
        Tk.set_value(e_nllevcal, conf["Noise Loudspeaker"]["Equalization"])
    end
    Tk.bind(b_nllevcal, "command", callback_update_noiseldspk)



    #
    ##
    ###
    page2 = Tk.Frame(nb)
    Tk.page_add(page2, "DUT")
    
    ##
    lf5 = Tk.Labelframe(page2, "Versions For Test")
    Tk.pack(lf5, expand=true, fill="both")

    e_sfv = Tk.Entry(lf5, width=80)
    e_hsv = Tk.Entry(lf5, width=80)
    e_ctv = Tk.Entry(lf5, width=80)
    e_stv = Tk.Entry(lf5, width=80)

    Tk.formlayout(e_sfv, "Samsung Firmware Version ")
    Tk.formlayout(e_hsv, "Harman Solution Version ")
    Tk.formlayout(e_ctv, "Capture Tuning Version ")
    Tk.formlayout(e_stv, "Speaker Tuning Version ")




    #
    ##
    ###
    function callback_conf2ui(path)
        if haskey(conf, "Use Turntable")
            Tk.set_value(cb_ut, conf["Use Turntable"])
        else
            Tk.set_value(cb_ut, false)
        end
        if haskey(conf, "Internal Signals")
            Tk.set_value(cb_cdis, conf["Internal Signals"])
        else
            Tk.set_value(cb_cdis, false)
        end
        if haskey(conf, "Clock Drift Compensation")
            Tk.set_value(cb_dcdc, conf["Clock Drift Compensation"])
        else
            Tk.set_value(cb_dcdc, false)
        end


        if haskey(conf, "Project")
            Tk.set_value(e_proj, conf["Project"])
        else
            Tk.set_value(e_proj, "")
        end
        if haskey(conf, "Version")
            Tk.set_value(e_ver, conf["Version"])
        else
            Tk.set_value(e_ver, "")
        end
        if haskey(conf, "Sample Rate")
            Tk.set_value(e_rate, string(conf["Sample Rate"]))
        else
            Tk.set_value(e_rate, "")
        end
        if haskey(conf, "Score Server IP")
            Tk.set_value(e_srv, conf["Score Server IP"])
        else
            Tk.set_value(e_srv, "")
        end

        if haskey(conf, "Reference Mic")
            Tk.set_value(e_rfport, string(Int.(conf["Reference Mic"]["Port"])))
            Tk.set_value(e_rflevcal, string(conf["Reference Mic"]["Level Calibration"]))
        else
            Tk.set_value(e_rfport, "")
            Tk.set_value(e_rflevcal, "")
        end

        if haskey(conf, "Artificial Mouth")
            Tk.set_value(e_amport, string(Int.(conf["Artificial Mouth"]["Port"])))
            Tk.set_value(e_amlevcal, string(conf["Artificial Mouth"]["Equalization"]))
        else
            Tk.set_value(e_amport, "")
            Tk.set_value(e_amlevcal, "")
        end

        if haskey(conf, "Noise Loudspeaker")
            Tk.set_value(e_nlport, string(Int.(conf["Noise Loudspeaker"]["Port"])))
            Tk.set_value(e_nllevcal, string(conf["Noise Loudspeaker"]["Equalization"]))
        else
            Tk.set_value(e_nlport, "")
            Tk.set_value(e_nllevcal, "")
        end

        if haskey(conf, "Samsung Firmware Version")
            Tk.set_value(e_sfv, conf["Samsung Firmware Version"])
        else
            Tk.set_value(e_sfv, "")
        end
        if haskey(conf, "Harman Solution Version")
            Tk.set_value(e_hsv, conf["Harman Solution Version"])
        else
            Tk.set_value(e_hsv, "")
        end
        if haskey(conf, "Capture Tuning Version")
            Tk.set_value(e_ctv, conf["Capture Tuning Version"])
        else
            Tk.set_value(e_ctv, "")
        end
        if haskey(conf, "Speaker Tuning Version")
            Tk.set_value(e_stv, conf["Speaker Tuning Version"])
        else
            Tk.set_value(e_stv, "")
        end

        if haskey(conf, "Task")
            for i in conf["Task"]
                if !haskey(tasktab, i["Topic"])
                    tab = Frame(nb)
                    Tk.page_add(tab, i["Topic"])
                    addelement(tab, i["Topic"])
                    element_setvalue(i, i["Topic"])
                    tasktab[i["Topic"]] = tab 
                else
                    element_setvalue(i, i["Topic"])
                end
            end
        else
            Tk.Messagebox(w, title="Warning", message = "No Tasks Found!")
        end
        Tk.Messagebox(w, title="Infomation", message = "Frontend updated to the backend")
    end 
    
    function callback_ui2conf(path)
        
        conf["Use Turntable"] = Tk.get_value(cb_ut)
        conf["Internal Signals"] = Tk.get_value(cb_cdis)
        conf["Clock Drift Compensation"] = Tk.get_value(cb_dcdc)

        conf["Project"] = Tk.get_value(e_proj)
        conf["Version"] = Tk.get_value(e_ver)
        conf["Sample Rate"] = parse(Int64, Tk.get_value(e_rate))
        conf["Score Server IP"] = Tk.get_value(e_srv)

        conf["Reference Mic"]["Port"] = str2array(Int, Tk.get_value(e_rfport))
        conf["Reference Mic"]["Level Calibration"] = Tk.get_value(e_rflevcal)

        conf["Artificial Mouth"]["Port"] = str2array(Int, Tk.get_value(e_amport))
        conf["Artificial Mouth"]["Equalization"] = Tk.get_value(e_amlevcal)

        conf["Noise Loudspeaker"]["Port"] = str2array(Int, Tk.get_value(e_nlport))
        conf["Noise Loudspeaker"]["Equalization"] = Tk.get_value(e_nllevcal)

        conf["Samsung Firmware Version"] = Tk.get_value(e_sfv)
        conf["Harman Solution Version"] = Tk.get_value(e_hsv)
        conf["Capture Tuning Version"] = Tk.get_value(e_ctv)
        conf["Speaker Tuning Version"] = Tk.get_value(e_stv)

        for i in conf["Task"]
            element_getvalue(i, i["Topic"])
        end
        Tk.Messagebox(w, title="Infomation", message = "Backend updated to the frontend")


    end 

    Tk.menu_add(omenu, Separator(w))
    Tk.menu_add(omenu, "Read Configurations", callback_conf2ui)
    Tk.menu_add(omenu, "Write Conficurations", callback_ui2conf)
    Tk.set_value(nb,1)

end







function newtab_entry()

    w = Tk.Toplevel("New Test Item")
    f = Tk.Frame(w)
    Tk.pack(f, expand=true, fill="both")
    
    e = Tk.Entry(f)
    Tk.formlayout(e, "Title(Test Item ID) ")
    Tk.focus(e)			## put keyboard focus on widget

    Tk.Messagebox(title="Action", message="Please enter the title...")
    val = Tk.get_value(e)
    Tk.destroy(w)
    val    
end

function str2array(T, s)
    y = split(s, ['[',',',']',' '])
    [parse(T, x) for x in y[.!isempty.(y)]]
end