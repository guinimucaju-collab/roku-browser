' Converte "#RRGGBBAA" (formato do nosso contrato JSON) para "0xRRGGBBAA"
' (formato aceito pelos campos "color" do SceneGraph)
function ToRokuColor(hex)
    if hex = invalid or Len(hex) < 7
        return "0x000000FF"
    end if
    return "0x" + Mid(hex, 2)
end function

' Retorna um valor numérico com fallback padrão, evitando erros de tipo
function GetNum(val, defaultVal)
    if val = invalid then return defaultVal
    t = type(val)
    if t = "float" or t = "integer" then return val
    return defaultVal
end function

' Percorre a árvore JSON (já vem com coordenadas ABSOLUTAS calculadas pelo servidor)
' e cria os nós SceneGraph correspondentes, todos direto no mesmo Group "root".
' Como o traversal é pré-ordem (pai antes dos filhos), a ordem de z-index sai
' correta automaticamente: fundos são adicionados antes do conteúdo por cima.
sub BuildAndAppendNode(nodeJson, root)
    if nodeJson = invalid then return

    nodeType = nodeJson.type
    style = nodeJson.style

    if style = invalid then style = {}

    x = GetNum(nodeJson.x, 0)
    y = GetNum(nodeJson.y, 0)
    w = GetNum(nodeJson.width, 0)
    h = GetNum(nodeJson.height, 0)

    if nodeType = "box"
        if style.backgroundColor <> invalid
            rect = CreateObject("roSGNode", "Rectangle")
            rect.translation = [x, y]
            rect.width = w
            rect.height = h
            rect.color = ToRokuColor(style.backgroundColor)

            ' borda opcional
            if style.borderColor <> invalid
                rect.borderColor = ToRokuColor(style.borderColor)
            end if
            if style.borderWidth <> invalid
                rect.borderWidth = GetNum(style.borderWidth, 0)
            end if

            ' marca como focável se solicitado
            if style.focusable = true
                rect.isFocusable = true
                rect.actionUrl = nodeJson.actionUrl
            end if

            root.appendChild(rect)
        end if

    else if nodeType = "text"
        label = CreateObject("roSGNode", "Label")
        label.translation = [x, y]
        label.width = w
        label.height = h
        label.text = style.content
        if style.content = invalid then label.text = ""
        label.color = ToRokuColor(style.color)
        label.wrap = true

        font = CreateObject("roSGNode", "Font")
        fontSize = GetNum(style.fontSize, 16)
        font.size = fontSize
        label.font = font

        if style.textAlign <> invalid
            label.horizAlign = style.textAlign
        end if

        if style.vertAlign <> invalid
            label.vertAlign = style.vertAlign
        end if

        ' texto também pode ser focável (ex: link de navegação)
        if style.focusable = true
            label.isFocusable = true
            label.actionUrl = nodeJson.actionUrl
        end if

        root.appendChild(label)

    else if nodeType = "image"
        if style.src <> invalid and style.src <> ""
            poster = CreateObject("roSGNode", "Poster")
            poster.translation = [x, y]
            poster.width = w
            poster.height = h
            poster.uri = style.src
            poster.loadDisplayMode = "scaleToFit"

            if style.borderColor <> invalid
                poster.borderColor = ToRokuColor(style.borderColor)
            end if
            if style.borderWidth <> invalid
                poster.borderWidth = GetNum(style.borderWidth, 0)
            end if

            if style.focusable = true
                poster.isFocusable = true
                poster.actionUrl = nodeJson.actionUrl
            end if

            root.appendChild(poster)
        end if

    else if nodeType = "button" or nodeType = "link"
        ' botão/link: renderiza como caixa com texto dentro, focável por padrão
        btn = CreateObject("roSGNode", "Rectangle")
        btn.translation = [x, y]
        btn.width = w
        btn.height = h
        btn.color = ToRokuColor(style.backgroundColor)
        if style.borderColor <> invalid
            btn.borderColor = ToRokuColor(style.borderColor)
        end if
        if style.borderWidth <> invalid
            btn.borderWidth = GetNum(style.borderWidth, 2)
        else
            btn.borderWidth = 2
        end if
        btn.isFocusable = true
        btn.actionUrl = nodeJson.actionUrl
        root.appendChild(btn)

        ' adiciona texto dentro do botão, se houver
        if nodeJson.label <> invalid and nodeJson.label <> ""
            btnLabel = CreateObject("roSGNode", "Label")
            btnLabel.translation = [x + 10, y + 10]
            btnLabel.width = w - 20
            btnLabel.height = h - 20
            btnLabel.text = nodeJson.label
            btnLabel.color = ToRokuColor(style.color)
            btnLabel.wrap = true

            btnFont = CreateObject("roSGNode", "Font")
            btnFont.size = GetNum(style.fontSize, 18)
            btnLabel.font = btnFont

            if style.textAlign <> invalid
                btnLabel.horizAlign = style.textAlign
            end if
            root.appendChild(btnLabel)
        end if
    end if

    children = nodeJson.children
    if children <> invalid
        for each child in children
            BuildAndAppendNode(child, root)
        end for
    end if
end sub

' Aplica um deslocamento vertical (scroll) em todos os nós do grupo root.
sub ApplyScroll(root, deltaY)
    if root = invalid then return

    children = root.getChildren()
    if children = invalid then return

    for each child in children
        trans = child.translation
        if trans <> invalid
            child.translation = [trans[0], trans[1] + deltaY]
        end if
    end for
end sub

' Retorna a maior coordenada Y + altura entre todos os nós, para saber o tamanho total do conteúdo.
function GetContentHeight(root)
    maxY = 0
    if root = invalid then return 0

    children = root.getChildren()
    if children <> invalid
        for each child in children
            trans = child.translation
            h = child.height
            if trans <> invalid and h <> invalid
                bottom = trans[1] + h
                if bottom > maxY
                    maxY = bottom
                end if
            end if
        end for
    end if
    return maxY
end function

' Retorna a menor coordenada Y entre todos os nós (posição do topo do conteúdo).
function GetContentTop(root)
    minY = 0
    found = false
    if root = invalid then return 0

    children = root.getChildren()
    if children <> invalid
        for each child in children
            trans = child.translation
            if trans <> invalid
                if not found or trans[1] < minY
                    minY = trans[1]
                    found = true
                end if
            end if
        end for
    end if
    return minY
end function