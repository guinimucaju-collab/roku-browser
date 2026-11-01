sub Main()
    screen = CreateObject("roSGScreen")
    if screen = invalid
        print "Main: falha ao criar roSGScreen"
        return
    end if

    m.port = CreateObject("roMessagePort")
    if m.port = invalid
        print "Main: falha ao criar roMessagePort"
        return
    end if

    screen.SetMessagePort(m.port)

    scene = screen.CreateScene("MainScene")
    if scene = invalid
        print "Main: falha ao criar MainScene"
        return
    end if

    screen.show()

    while true
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed()
                return
            end if
        else if msgType = "roSGNodeEvent"
            ' eventos de nó podem ser tratados aqui futuramente
        end if
    end while
end sub