sub Main()
    screen = CreateObject("roSGScreen")
    if screen = invalid then return

    port = CreateObject("roMessagePort")
    if port = invalid then return

    screen.SetMessagePort(port)

    scene = screen.CreateScene("MainScene")
    if scene = invalid then return

    screen.show()

    while true
        msg = wait(0, port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub