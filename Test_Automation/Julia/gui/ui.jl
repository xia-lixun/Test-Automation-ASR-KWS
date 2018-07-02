
function demo_radio()
    w = Toplevel()
    f = Frame(w)
    pack(f, expand=true, fill="both")
    
    l  = Label(f, "Which do you prefer?")
    rb = Radio(f, ["apples", "oranges"])
    b  = Button(f, "ok")
    map(u -> pack(u, anchor="w"), (l, rb, b))     ## pack in left to right
    
    
    function callback(path)
      msg = (get_value(rb) == "apples") ? "Good choice!  An apple a day keeps the doctor away!" :
                                          "Good choice!  Oranges are full of Vitamin C!"
      Messagebox(w, msg)
    end
    
    bind(b, "command", callback)
end



function demo_wintab()
    w = Toplevel()
    tcl("pack", "propagate", w, false)
    nb = Notebook(w)
    pack(nb, expand=true, fill="both")

    page1 = Frame(nb)
    page_add(page1, "Tab 1")
    pack(Button(page1, "page 1"))

    page2 = Frame(nb)
    page_add(page2, "Tab 2")
    lf1 = Labelframe(page2, "Group Region 1")
    pack(lf1, expand=true, fill="both")
    lf2 = Labelframe(page2, "Group Region 2")
    pack(lf2, expand=true, fill="both")
    pack(Label(page2, "Some label"))

    set_value(nb, 2)		## position on page 2


end


function demo_progressbar()
    w = Toplevel("Code Name")
    f = Frame(w)
    pack(f, expand=true, fill="both")
    
    pb = Progressbar(f)
    pt = Label(f, "Progress 0%")
    #pt[:textvariable] = get_value(pb)
    
    grid(pb,1,1,sticky="ew")
    grid(pt,1,2,sticky="nw")
    #grid_columnconfigure(f,1,weight=1)

    set_value(pb, 77)
    pt[:text] = "Progress 77%"
end





function ui_tk()
    w = Tk.Toplevel("Automatic Audio Test Tool - CoC Suzhou", 800, 600)
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

    menu_add(fmenu, "Open File...", loadconf)
    menu_add(fmenu, "Save As...", saveconf)
    menu_add(fmenu, Separator(w))
    menu_add(fmenu, "Close Tool", (path)->destroy(w))
    

    cb_ut = Checkbutton(w, "Use Turntable")
    set_value(cb_ut, true)
    menu_add(omenu, cb_ut)

    cb_cdis = Checkbutton(w, "Capture DUT Internal Signals")
    set_value(cb_cdis, true)
    menu_add(omenu, cb_cdis)
    
    cb_dcdc = Checkbutton(w, "DUT Clock Drift Compensation")
    set_value(cb_dcdc, true)
    menu_add(omenu, cb_dcdc)
    menu_add(omenu, Separator(w))

    # rb = Radio(w, ["option 1", "option 2"])
    # set_value(rb, "option 1")
    # menu_add(omenu, rb)
    
    menu_add(hmenu, "Help...", (path)->println("open help file"))
    menu_add(hmenu, Separator(w))
    menu_add(hmenu, "About", (path)->Messagebox(w, title="Author", message="Xia Lixun"))



    #
    ##
    nb = Notebook(w)
    pack(nb, expand=true, fill="both")

    function newtasktab(path)
        tasktab = Frame(nb)
        page_add(tasktab, newtab_entry())
        tasktab
    end
    menu_add(omenu, "New Test Item...", newtasktab)



    
    #
    # system config 
    page1 = Tk.Frame(nb)
    Tk.page_add(page1, "System Configurations")

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
    page2 = Frame(nb)
    page_add(page2, "DUT Configurations")
    
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

        # msg = "You have a nice name $val"
        # Messagebox(w,  msg)
    end  
    menu_add(omenu, Separator(w))
    menu_add(omenu, "Read Configurations", callback_conf2ui)


    set_value(nb,1)

    # function callback(path)
    #     Messagebox(w, title="OK", message="good")
    # end
    # bind(page1_b, "command", callback)
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
    [parse(T, x) for x in split(s, ['[',',',']'])[2:end-1]]
end