# Tk.jl:
# In c:\Users\...\.julia\v0.6\Tk\src there is a source tkwidget.jl written in Julia. There do the follow replacements.
#     Replace print_escaped (depreciated) by escape_string.
#     Replace takebuf_string(b) (depreciated) by String(take!(b)) where b is any parameter.
using Tk


function demo_checkbutton()

    w = Toplevel("Project Blahblah")
    f = Frame(w)
    pack(f, expand = true, fill = "both")
    cb = Checkbutton(f, "I like Julia")
    pack(cb)

    function callback(path)
        value = get_value(cb)
        msg = value ? "Glad to hear that" : "Sorry to hear that"
        Messagebox(w, title="Thanks for the feedback", message = msg)
    end
    bind(cb, "command", callback)

end



function demo_radiobutton()

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
    set_items(rb.buttons[1], "Fuji Apple")
    end

    bind(b, "command", callback)
end



function demo_menu()

    w = Toplevel()
    tcl("pack", "propagate", w, false) ## or pack_stop_propagate(w)
    
    mb = Menu(w)			## makes menu, adds to top-level window
    fmenu = menu_add(mb, "File")
    omenu = menu_add(mb, "Options")
    
    menu_add(fmenu, "Open file...", (path) -> println("Open file dialog, ..."))
    menu_add(fmenu, Separator(w))	## second argument is Tk_Separator instance
    menu_add(fmenu, "Close window", (path) -> destroy(w))
    
    cb = Checkbutton(w, "Something visible")
    set_value(cb, true)		## initialize
    menu_add(omenu, cb)		## second argument is Tk_Checkbutton instance
    
    menu_add(omenu, Separator(w))	## put in a separator
    
    rb = Radio(w, ["option 1", "option 2"])
    set_value(rb, "option 1")	## initialize
    menu_add(omenu, rb)		## second argument is Tk_Radio instance
    
    b = Button(w, "print selected options")
    pack(b, expand=true, fill="both")
    
    function callback(path)
      vals = map(get_value, (cb, rb))
      println(vals)
    end
    
    callback_add(b, callback)	## generic way to add callback for most common event
        
end



function demo_entry()

    w = Toplevel()
    f = Frame(w)
    pack(f, expand=true, fill="both")
    
    e = Entry(f)
    b = Button(f, "Ok")
    
    formlayout(e, "First name:")
    formlayout(b, nothing)
    focus(e)			## put keyboard focus on widget
    
    function callback(path)
      val = get_value(e)
      msg = "You have a nice name $val"
      Messagebox(w,  msg)
    end
    
    bind(b, "command", callback)
    bind(b, "<Return>", callback)
    bind(e, "<Return>", callback)  ## bind to a certain key press event    
end



function demo_listbox()

    fruits = ["Apple", "Navel orange", "Banana", "Pear"]
    w = Toplevel("Favorite fruit?")
    tcl("pack", "propagate", w, false)
    f = Frame(w)
    pack(f, expand=true, fill="both")
    
    f1 = Frame(f)			## need internal frame for use with scrollbars
    lb = Treeview(f1, fruits)
    lb[:selectmode] = "extended"  # "browse" or "none"
    scrollbars_add(f1, lb)
    pack(f1,  expand=true, fill="both")
    
    b = Button(f, "Ok")
    pack(b)
    
    bind(b, "command") do path	## do style
         fruit_choice = get_value(lb)
         msg = (fruit_choice == nothing) ? "What, no choice?" : "Good choice! $(fruit_choice[1])" * "s are delicious!"
         Messagebox(w,  msg)
    end
    
end



function demo_combobox()

    fruits = ["Apple", "Navel orange", "Banana", "Pear"]

    w = Toplevel("Combo boxes", 300, 200)
    tcl("pack", "propagate", w, false)
    f = Frame(w); pack(f, expand=true, fill="both")
    
    grid(Label(f, "Again, What is your favorite fruit?"), 1, 1)
    cb = Combobox(f, fruits)
    grid(cb, 2,1, sticky="ew")
    
    b = Button(f, "Ok")
    grid(b, 3, 1)
    
    function callback(path)
      fruit_choice = get_value(cb)
      msg = (fruit_choice == nothing) ? "What, no choice?" :
                                        "Good choice! $(fruit_choice)" * "s are delicious!"
      Messagebox(w, msg)
    end
    
    bind(b, "command", callback)
end



function demo_textwindow()
    w = Toplevel()
    tcl("pack", "propagate", w, false)
    f = Frame(w)
    txt = Text(f)
    scrollbars_add(f, txt)
    pack(f, expand=true, fill = "both")

    set_value(txt, "Long time ago there is ...")
    println(get_value(txt))
end



function demo_slider()
    
    w = Toplevel()
    f = Frame(w)
    pack(f, expand=true, fill="both")
    pack(Label(f, "Int Range slider"), side="top")
    s_range = Slider(f, 1:100)

    sp = Spinbox(f, 1:100)
    map(pack, (s_range, sp))

    pack(s_range, side="top", expand=true, fill="both", anchor="w")
    #bind(s_range, "command", path -> println("The range value is $(floor(Int,get_value(s_range)))"))
    
    function callback(path)
        set_value(sp, floor(Int,get_value(s_range)))
        println("The range value is $(floor(Int,get_value(s_range)))")
    end

    function callback_sp(path)
        set_value(s_range, get_value(sp))
        println("The range value is $(floor(Int,get_value(s_range)))")
    end
    bind(s_range, "command", callback)
    bind(sp, "command", callback_sp )

    pack(Label(f, "Float slider"), side="top")
    s_float = Slider(f, 0.0, 1.0)
    pack(s_float, side="top", expand=true, fill="both", anchor="w")
    bind(s_float, "command", path -> println("The float value is $(get_value(s_float))"))
end


function demo_notebook()

    w = Toplevel()
    tcl("pack", "propagate", w, false)
    nb = Notebook(w)
    pack(nb, expand=true, fill="both")
    
    page1 = Frame(nb)
    page_add(page1, "Tab 1")
    pack(Button(page1, "page 1"))
    
    page2 = Frame(nb)
    page_add(page2, "Tab 2")
    pack(Label(page2, "Some label"))
    
    set_value(nb, 2)		## position on page 2
end


function demo_panewindow()
    
    w = Toplevel("Panedwindow", 800, 300)
    tcl("pack", "propagate", w, false)
    f = Frame(w); pack(f, expand=true, fill="both")
    
    pg = Panedwindow(f, "horizontal") ## orientation. Use "vertical" for up down.
    grid(pg, 1, 1, sticky = "news")
    
    page_add(Button(pg, "button"))
    page_add(Label(pg, "label"))
    
    f = Frame(pg)
    formlayout(Entry(f), "Name:")
    formlayout(Entry(f), "Rank:")
    formlayout(Entry(f), "Serial Number:")
    page_add(f)
    
    set_value(pg, 100)                 ## set divider between first two pixels
    tcl(pg, "sashpos", 1, 200)	   ## others set the tcl way
end