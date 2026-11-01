' ATENÇÃO: troque pela URL real do seu deploy no Vercel (sem a barra final)
m.serverBase = "https://SEU-DEPLOY.vercel.app/api/translate"

sub init()
    m.root = m.top.findNode("root")
    m.loadingLabel = m.top.findNode("loadingLabel")
    m.statusLabel = m.top.findNode("statusLabel")

    ' URL de teste padrão
    if m.top.pageUrl = invalid or m.top.pageUrl = ""
        m.top.pageUrl = "https://exemplo.com"
    end if

    StartTranslation(m.top.pageUrl)
end sub

sub onPageUrlChange()
    ClearContent()
    m.top.status = "Buscando página..."
    StartTranslation(m.top.pageUrl)
end sub

sub StartTranslation(pageUrl)
    if m.loadingLabel <> invalid
        m.loadingLabel.visible = true
    end if

    m.task = CreateObject("roSGNode", "TranslateTask")
    m.task.serverUrl = m.serverBase + "?url=" + HttpEncode(pageUrl)
    m.task.ObserveField("content", "OnContentReceived")
    m.task.ObserveField("error", "OnTaskError")
    m.task.control = "RUN"
end sub

sub OnContentReceived(event as Object)
    if m.loadingLabel <> invalid
        m.loadingLabel.visible = false
    end if

    content = event.GetData()

    if content = invalid
        ShowError("Não foi possível carregar a página. Verifique a URL e o servidor.")
        return
    end if

    rootNode = content.root
    if rootNode <> invalid
        ClearContent()
        BuildAndAppendNode(rootNode, m.root)
        m.top.status = "Página carregada com sucesso."
    else
        ShowError("Resposta do servidor inválida.")
    end if
end sub

sub OnTaskError(event as Object)
    if m.loadingLabel <> invalid
        m.loadingLabel.visible = false
    end if

    ShowError("Erro de rede. Pressione Replay para tentar novamente.")
end sub

sub ClearContent()
    children = m.root.getChildren()
    if children <> invalid
        for each child in children
            m.root.removeChild(child)
        end for
    end if
end sub

sub ShowError(msg)
    if m.statusLabel <> invalid
        m.statusLabel.text = msg
        m.statusLabel.color = "0xFF4444FF"
    end if
    m.top.status = msg
end sub

sub ShowStatus(msg)
    if m.statusLabel <> invalid
        m.statusLabel.text = msg
        m.statusLabel.color = "0xFFFF00FF"
    end if
    m.top.status = msg
end sub

' Escapa a URL de destino pra usar como query param
function HttpEncode(str)
    xfer = CreateObject("roUrlTransfer")
    return xfer.Escape(str)
end function

function onKeyEvent(key, press)
    if not press then return false

    if key = "back"
        return false
    end if

    if key = "replay" or key = "enter" or key = "play"
        onPageUrlChange()
        return true
    end if

    if key = "home"
        return false
    end if

    return false
end function