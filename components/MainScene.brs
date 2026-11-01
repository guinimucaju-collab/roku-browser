' ATENÇÃO: troque pela URL real do seu deploy no Vercel (sem a barra final)
m.serverBase = "https://SEU-DEPLOY.vercel.app/api/translate"

m.maxRetries = 2
m.retryCount = 0
m.pageHistory = []          ' pilha de URLs visitadas (para navegar com Back)
m.maxHistory = 10
m.focusedIndex = -1         ' índice do elemento atualmente em foco
m.focusableNodes = []       ' lista de nós que podem receber foco
m.lastPageUrl = ""          ' cache da última URL carregada

sub init()
    m.root = m.top.findNode("root")
    m.loadingLabel = m.top.findNode("loadingLabel")
    m.statusLabel = m.top.findNode("statusLabel")

    ' torna a cena focável para capturar eventos do controle remoto
    m.top.setFocus(true)

    ' URL de teste padrão
    if m.top.pageUrl = invalid or m.top.pageUrl = ""
        m.top.pageUrl = "https://exemplo.com"
    end if

    ' adiciona a URL inicial ao histórico e cache
    if m.top.pageUrl <> invalid and m.top.pageUrl <> ""
        m.pageHistory.push(m.top.pageUrl)
        m.lastPageUrl = m.top.pageUrl
    end if

    StartTranslation(m.top.pageUrl)
end sub

sub onPageUrlChange()
    ' limpa o conteúdo anterior antes de buscar a nova página
    ClearContent()
    ResetFocus()
    m.top.status = "Buscando página..."
    m.retryCount = 0
    StartTranslation(m.top.pageUrl)
end sub

sub StartTranslation(pageUrl as String)
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
    m.retryCount = 0  ' reset retry ao sucesso

    if content = invalid
        HandleError("Não foi possível carregar a página. Verifique a URL e o servidor.")
        return
    end if

    rootNode = content.root
    if rootNode <> invalid
        ClearContent()
        ResetFocus()
        BuildAndAppendNode(rootNode, m.root)
        RebuildFocusList()
        m.top.status = "Página carregada com sucesso."
        ' salva no cache
        if m.top.pageUrl <> invalid
            m.lastPageUrl = m.top.pageUrl
        end if
    else
        HandleError("Resposta do servidor inválida.")
    end if
end sub

sub OnTaskError(event as Object)
    if m.loadingLabel <> invalid
        m.loadingLabel.visible = false
    end if

    errMsg = event.GetData()
    if errMsg = invalid then errMsg = "Erro desconhecido na tarefa"

    ' tenta retry se ainda não excedeu o limite
    if m.retryCount < m.maxRetries
        m.retryCount = m.retryCount + 1
        m.top.status = "Tentando novamente (" + Str(m.retryCount) + "/" + Str(m.maxRetries) + ")..."
        StartTranslation(m.top.pageUrl)
        return
    end if

    HandleError(errMsg)
end sub

sub HandleError(msg as String)
    ShowError(msg)
end sub

sub ClearContent()
    ' remove todos os filhos do grupo root
    children = m.root.getChildren()
    if children <> invalid
        for each child in children
            m.root.removeChild(child)
        end for
    end if
end sub

sub ShowError(msg as String)
    if m.statusLabel <> invalid
        m.statusLabel.text = msg
        m.statusLabel.color = "0xFF4444FF"
    end if
    m.top.status = msg
end sub

sub ShowStatus(msg as String)
    if m.statusLabel <> invalid
        m.statusLabel.text = msg
        m.statusLabel.color = "0xFFFF00FF"
    end if
    m.top.status = msg
end sub

' Escapa a URL de destino pra usar como query param
function HttpEncode(str as String) as String
    xfer = CreateObject("roUrlTransfer")
    return xfer.Escape(str)
end function

' Adiciona uma URL ao histórico de navegação (evita duplicatas consecutivas)
sub AddToHistory(url as String)
    if url = invalid or url = "" then return

    if m.pageHistory.count() > 0
        last = m.pageHistory[m.pageHistory.count() - 1]
        if last = url then return
    end if

    m.pageHistory.push(url)

    while m.pageHistory.count() > m.maxHistory
        m.pageHistory.shift()
    end while
end sub

' Navega para a URL anterior no histórico
sub GoBack()
    if m.pageHistory.count() <= 1 then return

    m.pageHistory.pop()
    previous = m.pageHistory[m.pageHistory.count() - 1]

    if previous <> m.top.pageUrl
        m.top.pageUrl = previous
    end if
end sub

' Reseta o estado de foco
sub ResetFocus()
    m.focusedIndex = -1
    m.focusableNodes = []
end sub

' Reconstrói a lista de elementos que podem receber foco (botões/links)
sub RebuildFocusList()
    m.focusableNodes = []
    CollectFocusableNodes(m.root, m.focusableNodes)
    if m.focusableNodes.count() > 0
        m.focusedIndex = 0
        ApplyFocusVisual(m.focusedIndex)
    end if
end sub

' Percorre a árvore de nós do SceneGraph coletando elementos focáveis
sub CollectFocusableNodes(node as Object, list as Object)
    if node = invalid then return

    ' verifica se o nó tem marcação de foco (campo personalizado "isFocusable")
    if node.isFocusable <> invalid and node.isFocusable = true
        list.push(node)
    end if

    children = node.getChildren()
    if children <> invalid
        for each child in children
            CollectFocusableNodes(child, list)
        end for
    end if
end sub

' Aplica destaque visual ao elemento focado (borda ao redor)
sub ApplyFocusVisual(index as Integer)
    ' remove destaque anterior
    if m.focusedIndex >= 0 and m.focusedIndex < m.focusableNodes.count()
        prevNode = m.focusableNodes[m.focusedIndex]
        if prevNode <> invalid
            prevNode.borderWidth = 0
            prevNode.borderColor = "0x00000000"
        end if
    end if

    ' aplica destaque ao novo
    if index >= 0 and index < m.focusableNodes.count()
        currNode = m.focusableNodes[index]
        if currNode <> invalid
            currNode.borderWidth = 4
            currNode.borderColor = "0x00AAFFFF"
            ' traz o elemento focado para a vista (scroll simples)
            BringIntoView(currNode)
        end if
    end if
end sub

' Tenta trazer o elemento focado para dentro da área visível (scroll básico)
sub BringIntoView(node as Object)
    if node = invalid then return

    trans = node.translation
    h = node.height
    if trans = invalid or h = invalid then return

    nodeBottom = trans[1] + h
    nodeTop = trans[1]

    ' se o elemento está muito abaixo da tela, rola para cima
    if nodeBottom > 700
        ApplyScrollBounded(m.root, 700 - nodeBottom)
    end if

    ' se o elemento está muito acima da tela, rola para baixo
    if nodeTop < 20
        ApplyScrollBounded(m.root, 20 - nodeTop)
    end if
end sub

' Aplica scroll com limite (não deixa o conteúdo sair completamente da tela)
sub ApplyScrollBounded(root as Object, deltaY as Integer)
    if root = invalid then return

    contentHeight = GetContentHeight(root)
    if contentHeight <= 720 then return

    children = root.getChildren()
    if children = invalid then return

    minY = 0
    maxY = 0
    for each child in children
        trans = child.translation
        if trans <> invalid
            if trans[1] < minY then minY = trans[1]
            if trans[1] > maxY then maxY = trans[1]
        end if
    end for

    newMinY = minY + deltaY
    if newMinY > 0 then newMinY = 0

    scrollLimit = 720 - contentHeight
    if newMinY < scrollLimit then newMinY = scrollLimit

    shift = newMinY - minY
    if shift = 0 then return

    for each child in children
        trans = child.translation
        if trans <> invalid
            child.translation = [trans[0], trans[1] + shift]
        end if
    end for
end sub

' Suporte a teclado/controle remoto
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back"
        if m.pageHistory.count() > 1
            GoBack()
            return true
        end if
        return false
    end if

    if key = "replay" or key = "enter" or key = "play"
        ' se há foco em um elemento clicável, executa a ação
        if m.focusedIndex >= 0 and m.focusedIndex < m.focusableNodes.count()
            focusedNode = m.focusableNodes[m.focusedIndex]
            if focusedNode <> invalid
                actionUrl = focusedNode.actionUrl
                if actionUrl <> invalid and actionUrl <> ""
                    m.top.pageUrl = actionUrl
                    AddToHistory(actionUrl)
                    onPageUrlChange()
                    return true
                end if
            end if
        end if
        ' senão, recarrega a página atual
        onPageUrlChange()
        return true
    end if

    if key = "home"
        return false
    end if

    ' navegação entre elementos focáveis com Up/Down
    if key = "up" and m.focusableNodes.count() > 0
        m.focusedIndex = m.focusedIndex - 1
        if m.focusedIndex < 0 then m.focusedIndex = m.focusableNodes.count() - 1
        ApplyFocusVisual(m.focusedIndex)
        return true
    end if

    if key = "down" and m.focusableNodes.count() > 0
        m.focusedIndex = m.focusedIndex + 1
        if m.focusedIndex >= m.focusableNodes.count() then m.focusedIndex = 0
        ApplyFocusVisual(m.focusedIndex)
        return true
    end if

    if key = "up"
        ApplyScrollBounded(m.root, -40)
        return true
    end if

    if key = "down"
        ApplyScrollBounded(m.root, 40)
        return true
    end if

    return false
end function