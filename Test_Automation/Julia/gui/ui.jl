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
    w = Toplevel("Automatic Audio Test Tool - CoC Suzhou", 800, 600)
    pack_stop_propagate(w)
   
    # menu
    m = Menu(w)
    fmenu = menu_add(m, "File")
    omenu = menu_add(m, "Options")
    hmenu = menu_add(m, "Help")

    menu_add(fmenu, "Open File...", (path)->println("open file dialog..."))
    menu_add(fmenu, Separator(w))
    menu_add(fmenu, "Close Tool", (path)->destroy(w))
    
    cb = Checkbutton(w, "something visible")
    set_value(cb, true)
    menu_add(omenu, cb)
    menu_add(omenu, Separator(w))
    rb = Radio(w, ["option 1", "option 2"])
    set_value(rb, "option 1")
    menu_add(omenu, rb)
    
    menu_add(hmenu, "Help...", (path)->println("open help file"))
    menu_add(hmenu, Separator(w))
    menu_add(hmenu, "About", (path)->Messagebox(w, title="Author", message="Xia Lixun"))


    # notebook
    nb = Notebook(w)
    pack(nb, expand=true, fill="both")

    # frames
    page1 = Frame(nb)
    page_add(page1, "Soundcard")
    lf1 = Labelframe(page1, "Microphone/Input Mixing Matrix")
    pack(lf1, expand=true, fill="both")
    
    grid(Label(lf1,"Port [1] -->"),2,1)
    grid(Label(lf1,"Port [2] -->"),3,1)
    grid(Label(lf1,"Port [3] -->"),4,1)
    grid(Label(lf1,"Port [4] -->"),5,1)

    grid(Label(lf1,"Reference Mic-1"),1,2)
    grid(Label(lf1,"Reference Mic-2"),1,3)
    grid(Label(lf1,"Reference Mic-3"),1,4)

    e_mmm = Array{Any}(4,3)
    for i = 2:5, j = 2:4
        e_mmm[i-1,j-1] = Entry(lf1)
        grid(e_mmm[i-1,j-1],i,j)
        set_value(e_mmm[i-1,j-1],"0.0")
    end



    lf2 = Labelframe(page1, "Loudspeaker/Output Mixing Matrix")
    pack(lf2, expand=true, fill="both")

    grid(Label(lf2,"Port [1] <--"),2,1)
    grid(Label(lf2,"Port [2] <--"),3,1)
    grid(Label(lf2,"Port [3] <--"),4,1)
    grid(Label(lf2,"Port [4] <--"),5,1)

    grid(Label(lf2,"Mouth 0.5m"),1,2)
    grid(Label(lf2,"Mouth 1.0m"),1,3)
    grid(Label(lf2,"Mouth 3.0m"),1,4)
    grid(Label(lf2,"Mouth 5.0m"),1,5)

    for i = 2:5, j = 2:5
        grid(Entry(lf2),i,j)
    end

    snd_stat = Label(page1, "[asio]: no device found")
    pack(snd_stat)
    if !isempty("SoundcardAPI.deviceCnt")
        snd_stat[:text] = "returned values" 
    end
    



    page2 = Frame(nb)
    page_add(page2, "Impulse Response")
    pack(Label(page2, "some labels"))

    set_value(nb,2)

    # function callback(path)
    #     Messagebox(w, title="OK", message="good")
    # end
    # bind(page1_b, "command", callback)
end