sub init()
    m.top.functionName = "FetchAndTranslate"
end sub

sub FetchAndTranslate()
    url = m.top.serverUrl
    m.top.error = ""

    xfer = CreateObject("roUrlTransfer")
    xfer.SetUrl(url)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.AddHeader("Accept", "application/json")

    ' timeout de 30 segundos para não travar o canal
    xfer.SetTimeout(30)

    response = xfer.GetToString()

    if response = invalid or response = ""
        print "TranslateTask: resposta vazia ou inválida"
        m.top.error = "resposta vazia do servidor"
        m.top.content = invalid
        return
    end if

    parsed = ParseJson(response)
    if parsed = invalid
        print "TranslateTask: falha ao fazer parse do JSON"
        m.top.error = "JSON inválido retornado pelo servidor"
        m.top.content = invalid
        return
    end if

    ' valida se o JSON tem a estrutura esperada (chave "root")
    if parsed.root = invalid
        print "TranslateTask: JSON sem chave 'root'"
        m.top.error = "estrutura JSON inválida (faltando 'root')"
        m.top.content = invalid
        return
    end if

    m.top.content = parsed
end sub