#include <open.mp>

/*
    RIO RISE - Gamemode para open.mp
    Arquivo: rio.pwn (versao corrigida)
*/

/* ============================================================
   CONFIGURACOES
   ============================================================ */

#define SALARIO_INTERVALO       (600000)
#define ANTISPAM_COMANDO        (1200)
#define ANTISPAM_CHAT           (900)
#define TAM_HASH                (65)
#define ARQUIVO_PREFIXO         "rio_"

#define DIALOG_REGISTRO         (1000)
#define DIALOG_LOGIN            (1001)
#define DIALOG_AJUDA            (1002)
#define DIALOG_EMPREGO          (1003)

#define COR_BRANCO              (0xFFFFFFFF)
#define COR_CINZA               (0xBFC3C7FF)
#define COR_VERDE               (0x43D17AFF)
#define COR_VERMELHO            (0xE74C3CFF)
#define COR_AMARELO             (0xF1C40FFF)

#define EMPREGO_NENHUM          (0)
#define EMPREGO_ENTREGADOR      (1)
#define EMPREGO_TAXISTA         (2)
#define EMPREGO_MECANICO        (3)

#define ESTADO_NAO_LOGADO       (0)
#define ESTADO_LOGADO           (1)

#define PRECO_COMBUSTIVEL       (50)

new gEstado[MAX_PLAYERS];
new gTentativas[MAX_PLAYERS];
new gNome[MAX_PLAYERS][MAX_PLAYER_NAME];
new gSenhaHash[MAX_PLAYERS][TAM_HASH];
new gDinheiro[MAX_PLAYERS];
new gSkin[MAX_PLAYERS];
new gAdmin[MAX_PLAYERS];
new gEmprego[MAX_PLAYERS];
new gBanido[MAX_PLAYERS];
new gClasse[MAX_PLAYERS];
new gUltimoComando[MAX_PLAYERS];
new gUltimaMensagem[MAX_PLAYERS];
new Float:gCombustivel[MAX_VEHICLES + 1];
new PlayerText:gTextdraw[MAX_PLAYERS];

new Float:gLocais[5][4] =
{
    { 1481.3220, -1738.2500, 13.5469, 90.0 },
    { 1174.8490, -1323.4600, 14.1200, 270.0 },
    { 1555.9200, -1675.6400, 16.1953, 180.0 },
    { 1035.5500, -1028.3200, 32.1016, 0.0 },
    { 2114.8200, -1784.1100, 13.5547, 180.0 }
};

forward AtualizarInterface();
forward PagarSalarios();

/* ============================================================
   FUNCOES AUXILIARES
   ============================================================ */

// Pega a palavra numero "indice" de um texto separado por espacos.
stock ExtrairToken(const texto[], indice, resultado[], tamanho)
{
    new atual = 0;
    new inicio = 0;
    new comprimento = strlen(texto);
    new i;
    new j;

    resultado[0] = EOS;

    for (i = 0; i <= comprimento; i++)
    {
        if (texto[i] == ' ' || texto[i] == EOS)
        {
            if (i > inicio)
            {
                if (atual == indice)
                {
                    for (j = 0; j < i - inicio && j < tamanho - 1; j++)
                    {
                        resultado[j] = texto[inicio + j];
                    }

                    resultado[j] = EOS;
                    return 1;
                }

                atual++;
            }

            inicio = i + 1;
        }
    }

    return 0;
}

// Copia tudo que vem depois da primeira palavra.
stock ObterResto(const texto[], resultado[], tamanho)
{
    new i = 0;
    new j = 0;

    resultado[0] = EOS;

    while (texto[i] != EOS && texto[i] != ' ')
    {
        i++;
    }

    while (texto[i] == ' ')
    {
        i++;
    }

    while (texto[i] != EOS && j < tamanho - 1)
    {
        resultado[j] = texto[i];
        j++;
        i++;
    }

    resultado[j] = EOS;
    return 1;
}

stock RemoverQuebraLinha(texto[])
{
    new tamanho = strlen(texto);

    while (tamanho > 0 && (texto[tamanho - 1] == '\n' || texto[tamanho - 1] == '\r'))
    {
        texto[tamanho - 1] = EOS;
        tamanho--;
    }

    return 1;
}

stock JogadorValido(id)
{
    if (id < 0 || id >= MAX_PLAYERS)
    {
        return 0;
    }

    if (!IsPlayerConnected(id))
    {
        return 0;
    }

    return 1;
}

stock DefinirDinheiro(playerid, valor)
{
    gDinheiro[playerid] = valor;
    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid, valor);
    return 1;
}

stock AdicionarDinheiro(playerid, valor)
{
    return DefinirDinheiro(playerid, gDinheiro[playerid] + valor);
}

stock ObterEmpregoNome(emprego, nome[], tamanho)
{
    switch (emprego)
    {
        case EMPREGO_ENTREGADOR:
        {
            format(nome, tamanho, "Entregador");
        }

        case EMPREGO_TAXISTA:
        {
            format(nome, tamanho, "Taxista");
        }

        case EMPREGO_MECANICO:
        {
            format(nome, tamanho, "Mecanico");
        }

        default:
        {
            format(nome, tamanho, "Nenhum");
        }
    }

    return 1;
}

stock SalarioDoEmprego(emprego)
{
    switch (emprego)
    {
        case EMPREGO_ENTREGADOR:
        {
            return 300;
        }

        case EMPREGO_TAXISTA:
        {
            return 450;
        }

        case EMPREGO_MECANICO:
        {
            return 550;
        }
    }

    return 100;
}

stock DefinirMotor(veiculo, estado)
{
    new motor;
    new luzes;
    new alarme;
    new portas;
    new capo;
    new portamalas;
    new objetivo;

    GetVehicleParamsEx(veiculo, motor, luzes, alarme, portas, capo, portamalas, objetivo);
    SetVehicleParamsEx(veiculo, estado, luzes, alarme, portas, capo, portamalas, objetivo);
    return 1;
}

/* ============================================================
   CONTAS (arquivos em scriptfiles/)
   Ordem das linhas: hash, dinheiro, skin, admin, emprego, banido
   ============================================================ */

stock ObterArquivoJogador(playerid, arquivo[], tamanho)
{
    format(arquivo, tamanho, "rio_%s.txt", gNome[playerid]);
    return 1;
}

stock CriarHashSenha(playerid, const senha[])
{
    SHA256_PassHash(senha, gNome[playerid], gSenhaHash[playerid], TAM_HASH);
    return 1;
}

stock SenhaCorreta(playerid, const senha[])
{
    new hashInformado[TAM_HASH];

    SHA256_PassHash(senha, gNome[playerid], hashInformado, TAM_HASH);

    if (strcmp(hashInformado, gSenhaHash[playerid], false) == 0)
    {
        return 1;
    }

    return 0;
}

stock SalvarConta(playerid)
{
    new arquivoNome[96];
    new linha[160];
    new File:arquivo;

    if (gNome[playerid][0] == EOS)
    {
        return 0;
    }

    ObterArquivoJogador(playerid, arquivoNome, sizeof arquivoNome);

    arquivo = fopen(arquivoNome, io_write);

    if (!arquivo)
    {
        return 0;
    }

    format(linha, sizeof linha, "%s\n", gSenhaHash[playerid]);
    fwrite(arquivo, linha);

    format(linha, sizeof linha, "%d\n", gDinheiro[playerid]);
    fwrite(arquivo, linha);

    format(linha, sizeof linha, "%d\n", gSkin[playerid]);
    fwrite(arquivo, linha);

    format(linha, sizeof linha, "%d\n", gAdmin[playerid]);
    fwrite(arquivo, linha);

    format(linha, sizeof linha, "%d\n", gEmprego[playerid]);
    fwrite(arquivo, linha);

    format(linha, sizeof linha, "%d\n", gBanido[playerid]);
    fwrite(arquivo, linha);

    fclose(arquivo);
    return 1;
}

stock CarregarConta(playerid)
{
    new arquivoNome[96];
    new linha[160];
    new File:arquivo;
    new numero = 0;

    ObterArquivoJogador(playerid, arquivoNome, sizeof arquivoNome);

    if (!fexist(arquivoNome))
    {
        return 0;
    }

    arquivo = fopen(arquivoNome, io_read);

    if (!arquivo)
    {
        return 0;
    }

    while (fread(arquivo, linha))
    {
        RemoverQuebraLinha(linha);

        switch (numero)
        {
            case 0:
            {
                format(gSenhaHash[playerid], TAM_HASH, "%s", linha);
            }

            case 1:
            {
                gDinheiro[playerid] = strval(linha);
            }

            case 2:
            {
                gSkin[playerid] = strval(linha);
            }

            case 3:
            {
                gAdmin[playerid] = strval(linha);
            }

            case 4:
            {
                gEmprego[playerid] = strval(linha);
            }

            case 5:
            {
                gBanido[playerid] = strval(linha);
            }
        }

        numero++;
    }

    fclose(arquivo);

    if (gSkin[playerid] < 0 || gSkin[playerid] > 311)
    {
        gSkin[playerid] = 7;
    }

    if (gEmprego[playerid] < EMPREGO_NENHUM || gEmprego[playerid] > EMPREGO_MECANICO)
    {
        gEmprego[playerid] = EMPREGO_NENHUM;
    }

    return 1;
}

stock InicializarJogador(playerid)
{
    gEstado[playerid] = ESTADO_NAO_LOGADO;
    gTentativas[playerid] = 0;
    gDinheiro[playerid] = 500;
    gSkin[playerid] = 7;
    gAdmin[playerid] = 0;
    gEmprego[playerid] = EMPREGO_NENHUM;
    gBanido[playerid] = 0;
    gClasse[playerid] = 0;
    gUltimoComando[playerid] = 0;
    gUltimaMensagem[playerid] = 0;
    gSenhaHash[playerid][0] = EOS;
    return 1;
}

/* ============================================================
   INTERFACE (textdraw com dinheiro e hora)
   ============================================================ */

stock CriarTextdraw(playerid)
{
    gTextdraw[playerid] = CreatePlayerTextDraw(playerid, 630.0, 22.0, "Rio Rise");
    PlayerTextDrawLetterSize(playerid, gTextdraw[playerid], 0.25, 1.1);
    PlayerTextDrawAlignment(playerid, gTextdraw[playerid], t_TEXT_DRAW_ALIGN:3);
    PlayerTextDrawColour(playerid, gTextdraw[playerid], COR_BRANCO);
    PlayerTextDrawSetShadow(playerid, gTextdraw[playerid], 1);
    PlayerTextDrawSetOutline(playerid, gTextdraw[playerid], 1);
    PlayerTextDrawBackgroundColour(playerid, gTextdraw[playerid], 0x000000FF);
    PlayerTextDrawFont(playerid, gTextdraw[playerid], t_TEXT_DRAW_FONT:1);
    PlayerTextDrawSetProportional(playerid, gTextdraw[playerid], true);
    PlayerTextDrawShow(playerid, gTextdraw[playerid]);
    return 1;
}

public AtualizarInterface()
{
    new i;
    new hora;
    new minuto;
    new segundo;
    new veiculo;
    new texto[128];

    gettime(hora, minuto, segundo);

    for (i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i) || gEstado[i] != ESTADO_LOGADO)
        {
            continue;
        }

        format(texto, sizeof texto, "Rio Rise~n~R$ %d~n~%02d:%02d", gDinheiro[i], hora, minuto);
        PlayerTextDrawSetString(i, gTextdraw[i], texto);

        // consumo de combustivel
        if (GetPlayerState(i) == PLAYER_STATE_DRIVER)
        {
            veiculo = GetPlayerVehicleID(i);

            if (veiculo > 0 && veiculo <= MAX_VEHICLES && gCombustivel[veiculo] > 0.0)
            {
                gCombustivel[veiculo] -= 0.1;

                if (gCombustivel[veiculo] <= 0.0)
                {
                    gCombustivel[veiculo] = 0.0;
                    DefinirMotor(veiculo, 0);
                    SendClientMessage(i, COR_VERMELHO, "Acabou o combustivel! Use /abastecer.");
                }
            }
        }
    }

    return 1;
}

/* ============================================================
   CHAT LOCAL
   ============================================================ */

stock EnviarProximo(playerid, const verbo[], const mensagem[], Float:alcance, cor)
{
    new Float:x;
    new Float:y;
    new Float:z;
    new nome[MAX_PLAYER_NAME];
    new texto[144];
    new i;

    GetPlayerPos(playerid, x, y, z);
    GetPlayerName(playerid, nome, sizeof nome);

    format(texto, sizeof texto, "%s %s: %s", nome, verbo, mensagem);

    for (i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i) || gEstado[i] != ESTADO_LOGADO)
        {
            continue;
        }

        if (IsPlayerInRangeOfPoint(i, alcance, x, y, z))
        {
            SendClientMessage(i, cor, texto);
        }
    }

    return 1;
}

/* ============================================================
   SALARIOS
   ============================================================ */

public PagarSalarios()
{
    new i;
    new valor;
    new emprego[32];
    new mensagem[144];

    for (i = 0; i < MAX_PLAYERS; i++)
    {
        if (!IsPlayerConnected(i) || gEstado[i] != ESTADO_LOGADO)
        {
            continue;
        }

        valor = SalarioDoEmprego(gEmprego[i]);
        AdicionarDinheiro(i, valor);
        ObterEmpregoNome(gEmprego[i], emprego, sizeof emprego);

        format(mensagem, sizeof mensagem, "Salario recebido: R$ %d (emprego: %s).", valor, emprego);
        SendClientMessage(i, COR_VERDE, mensagem);

        SalvarConta(i);
    }

    return 1;
}

/* ============================================================
   DIALOGOS
   ============================================================ */

stock MostrarRegistro(playerid, const texto[])
{
    ShowPlayerDialog(playerid, DIALOG_REGISTRO, DIALOG_STYLE_PASSWORD, "Rio Rise - Registro", texto, "Registrar", "Sair");
    return 1;
}

stock MostrarLogin(playerid, const texto[])
{
    ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Rio Rise - Login", texto, "Entrar", "Sair");
    return 1;
}

stock MostrarAjuda(playerid)
{
    new texto[700];

    texto[0] = EOS;
    strcat(texto, "/carro [modelo 400-611]\n", sizeof texto);
    strcat(texto, "/skin [id 0-311]\n", sizeof texto);
    strcat(texto, "/reparar\n", sizeof texto);
    strcat(texto, "/combustivel\n", sizeof texto);
    strcat(texto, "/abastecer (R$ 50)\n", sizeof texto);
    strcat(texto, "/tp [centro/hospital/delegacia/oficina/praia]\n", sizeof texto);
    strcat(texto, "/pagar [id] [valor]\n", sizeof texto);
    strcat(texto, "/emprego\n", sizeof texto);
    strcat(texto, "/g [mensagem] - gritar\n", sizeof texto);
    strcat(texto, "/s [mensagem] - sussurrar\n", sizeof texto);
    strcat(texto, "/ajuda\n\n", sizeof texto);
    strcat(texto, "Admin:\n", sizeof texto);
    strcat(texto, "/kick [id] (nivel 1)\n", sizeof texto);
    strcat(texto, "/irpara [id] (nivel 1)\n", sizeof texto);
    strcat(texto, "/trazer [id] (nivel 1)\n", sizeof texto);
    strcat(texto, "/ban [id] (nivel 2)\n", sizeof texto);
    strcat(texto, "/setdinheiro [id] [valor] (nivel 3)", sizeof texto);

    ShowPlayerDialog(playerid, DIALOG_AJUDA, DIALOG_STYLE_MSGBOX, "Rio Rise - Ajuda", texto, "Fechar", "");
    return 1;
}

stock MostrarEmpregos(playerid)
{
    ShowPlayerDialog(
        playerid,
        DIALOG_EMPREGO,
        DIALOG_STYLE_LIST,
        "Rio Rise - Empregos",
        "Entregador - R$ 300\nTaxista - R$ 450\nMecanico - R$ 550",
        "Escolher",
        "Cancelar"
    );

    return 1;
}

/* ============================================================
   CALLBACKS
   ============================================================ */

public OnGameModeInit()
{
    new v;

    SetGameModeText("Rio Rise");
    UsePlayerPedAnims();
    ShowPlayerMarkers(PLAYER_MARKERS_MODE_OFF);
    DisableInteriorEnterExits();

    // classe 0 civil, 1 policial, 2 medico, 3 mecanico
    AddPlayerClass(7,   1481.3220, -1738.2500, 13.5469, 90.0, WEAPON_FIST, 0, WEAPON_FIST, 0, WEAPON_FIST, 0);
    AddPlayerClass(280, 1555.9200, -1675.6400, 16.1953, 180.0, WEAPON_FIST, 0, WEAPON_FIST, 0, WEAPON_FIST, 0);
    AddPlayerClass(274, 1174.8490, -1323.4600, 14.1200, 270.0, WEAPON_FIST, 0, WEAPON_FIST, 0, WEAPON_FIST, 0);
    AddPlayerClass(50,  1035.5500, -1028.3200, 32.1016, 0.0, WEAPON_FIST, 0, WEAPON_FIST, 0, WEAPON_FIST, 0);

    for (v = 0; v <= MAX_VEHICLES; v++)
    {
        gCombustivel[v] = 100.0;
    }

    SetTimer("AtualizarInterface", 1000, true);
    SetTimer("PagarSalarios", SALARIO_INTERVALO, true);

    return 1;
}

public OnPlayerConnect(playerid)
{
    InicializarJogador(playerid);
    GetPlayerName(playerid, gNome[playerid], MAX_PLAYER_NAME);
    CriarTextdraw(playerid);

    if (CarregarConta(playerid))
    {
        if (gBanido[playerid] == 1)
        {
            SendClientMessage(playerid, COR_VERMELHO, "Esta conta esta banida.");
            Kick(playerid);
            return 1;
        }

        MostrarLogin(playerid, "Digite a senha da sua conta:");
    }
    else
    {
        MostrarRegistro(playerid, "Digite uma senha para criar sua conta:");
    }

    return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
    if (gEstado[playerid] == ESTADO_LOGADO)
    {
        SalvarConta(playerid);
    }

    gEstado[playerid] = ESTADO_NAO_LOGADO;
    return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
    gClasse[playerid] = classid;
    return 1;
}

public OnPlayerRequestSpawn(playerid)
{
    if (gEstado[playerid] != ESTADO_LOGADO)
    {
        SendClientMessage(playerid, COR_VERMELHO, "Voce precisa fazer login primeiro.");
        return 0;
    }

    return 1;
}

public OnPlayerSpawn(playerid)
{
    // civil usa a skin salva; as outras classes usam a skin da propria classe
    if (gClasse[playerid] == 0)
    {
        SetPlayerSkin(playerid, gSkin[playerid]);
    }

    ResetPlayerMoney(playerid);
    GivePlayerMoney(playerid, gDinheiro[playerid]);

    SendClientMessage(playerid, COR_VERDE, "Bem-vindo a Rio Rise. Use /ajuda para ver os comandos.");
    return 1;
}

public OnPlayerText(playerid, text[])
{
    new agora = GetTickCount();

    if (gEstado[playerid] != ESTADO_LOGADO)
    {
        return 0;
    }

    if (agora - gUltimaMensagem[playerid] < ANTISPAM_CHAT)
    {
        SendClientMessage(playerid, COR_VERMELHO, "Aguarde antes de enviar outra mensagem.");
        return 0;
    }

    gUltimaMensagem[playerid] = agora;
    EnviarProximo(playerid, "diz", text, 35.0, COR_BRANCO);

    return 0;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    new mensagem[144];
    new emprego[32];

    if (dialogid == DIALOG_REGISTRO)
    {
        if (!response)
        {
            Kick(playerid);
            return 1;
        }

        if (strlen(inputtext) < 4 || strlen(inputtext) > 32)
        {
            MostrarRegistro(playerid, "A senha deve ter entre 4 e 32 caracteres:");
            return 1;
        }

        CriarHashSenha(playerid, inputtext);
        gEstado[playerid] = ESTADO_LOGADO;
        gSkin[playerid] = 7;
        DefinirDinheiro(playerid, 500);
        SalvarConta(playerid);

        SendClientMessage(playerid, COR_VERDE, "Conta registrada com sucesso.");
        SpawnPlayer(playerid);
        return 1;
    }

    if (dialogid == DIALOG_LOGIN)
    {
        if (!response)
        {
            Kick(playerid);
            return 1;
        }

        if (!SenhaCorreta(playerid, inputtext))
        {
            gTentativas[playerid]++;

            if (gTentativas[playerid] >= 3)
            {
                SendClientMessage(playerid, COR_VERMELHO, "Muitas tentativas incorretas.");
                Kick(playerid);
                return 1;
            }

            MostrarLogin(playerid, "Senha incorreta. Tente novamente:");
            return 1;
        }

        gEstado[playerid] = ESTADO_LOGADO;
        DefinirDinheiro(playerid, gDinheiro[playerid]);

        SendClientMessage(playerid, COR_VERDE, "Login efetuado com sucesso.");
        SpawnPlayer(playerid);
        return 1;
    }

    if (dialogid == DIALOG_EMPREGO)
    {
        if (!response)
        {
            return 1;
        }

        gEmprego[playerid] = listitem + 1;
        ObterEmpregoNome(gEmprego[playerid], emprego, sizeof emprego);

        format(mensagem, sizeof mensagem, "Seu novo emprego e: %s.", emprego);
        SendClientMessage(playerid, COR_VERDE, mensagem);

        SalvarConta(playerid);
        return 1;
    }

    return 0;
}

/* ============================================================
   COMANDOS
   ============================================================ */

public OnPlayerCommandText(playerid, cmdtext[])
{
    new agora = GetTickCount();
    new cmd[32];
    new arg1[64];
    new arg2[64];
    new resto[128];
    new mensagem[144];
    new nomeAlvo[MAX_PLAYER_NAME];
    new alvo;
    new valor;
    new modelo;
    new local;
    new veiculo;
    new Float:x;
    new Float:y;
    new Float:z;
    new Float:angulo;

    if (gEstado[playerid] != ESTADO_LOGADO)
    {
        SendClientMessage(playerid, COR_VERMELHO, "Voce precisa fazer login primeiro.");
        return 1;
    }

    if (agora - gUltimoComando[playerid] < ANTISPAM_COMANDO)
    {
        SendClientMessage(playerid, COR_VERMELHO, "Aguarde antes de usar outro comando.");
        return 1;
    }

    gUltimoComando[playerid] = agora;

    ExtrairToken(cmdtext, 0, cmd, sizeof cmd);
    ExtrairToken(cmdtext, 1, arg1, sizeof arg1);
    ExtrairToken(cmdtext, 2, arg2, sizeof arg2);
    ObterResto(cmdtext, resto, sizeof resto);

    if (!strcmp(cmd, "/ajuda", true))
    {
        MostrarAjuda(playerid);
        return 1;
    }

    if (!strcmp(cmd, "/emprego", true))
    {
        MostrarEmpregos(playerid);
        return 1;
    }

    if (!strcmp(cmd, "/reparar", true))
    {
        veiculo = GetPlayerVehicleID(playerid);

        if (veiculo == 0)
        {
            SendClientMessage(playerid, COR_VERMELHO, "Voce precisa estar em um veiculo.");
            return 1;
        }

        RepairVehicle(veiculo);
        SendClientMessage(playerid, COR_VERDE, "Veiculo reparado.");
        return 1;
    }

    if (!strcmp(cmd, "/combustivel", true))
    {
        veiculo = GetPlayerVehicleID(playerid);

        if (veiculo == 0 || veiculo > MAX_VEHICLES)
        {
            SendClientMessage(playerid, COR_VERMELHO, "Voce precisa estar em um veiculo.");
            return 1;
        }

        format(mensagem, sizeof mensagem, "Combustivel: %.1f%%", gCombustivel[veiculo]);
        SendClientMessage(playerid, COR_AMARELO, mensagem);
        return 1;
    }

    if (!strcmp(cmd, "/abastecer", true))
    {
        veiculo = GetPlayerVehicleID(playerid);

        if (veiculo == 0 || veiculo > MAX_VEHICLES)
        {
            SendClientMessage(playerid, COR_VERMELHO, "Voce precisa estar em um veiculo.");
            return 1;
        }

        if (gDinheiro[playerid] < PRECO_COMBUSTIVEL)
        {
            SendClientMessage(playerid, COR_VERMELHO, "Dinheiro insuficiente (R$ 50).");
            return 1;
        }

        AdicionarDinheiro(playerid, -PRECO_COMBUSTIVEL);
        gCombustivel[veiculo] = 100.0;
        DefinirMotor(veiculo, 1);

        SendClientMessage(playerid, COR_VERDE, "Tanque cheio por R$ 50.");
        SalvarConta(playerid);
        return 1;
    }

    if (!strcmp(cmd, "/g", true))
    {
        if (resto[0] == EOS)
        {
            SendClientMessage(playerid, COR_AMARELO, "Uso correto: /g [mensagem]");
            return 1;
        }

        EnviarProximo(playerid, "grita", resto, 70.0, COR_AMARELO);
        return 1;
    }

    if (!strcmp(cmd, "/s", true))
    {
        if (resto[0] == EOS)
        {
            SendClientMessage(playerid, COR_CINZA, "Uso correto: /s [mensagem]");
            return 1;
        }

        EnviarProximo(playerid, "sussurra", resto, 8.0, COR_CINZA);
        return 1;
    }

    if (!strcmp(cmd, "/carro", true))
    {
        modelo = strval(arg1);

        if (arg1[0] == EOS || modelo < 400 || modelo > 611)
        {
            SendClientMessage(playerid, COR_AMARELO, "Uso correto: /carro [modelo 400-611]");
            return 1;
        }

        GetPlayerPos(playerid, x, y, z);
        GetPlayerFacingAngle(playerid, angulo);

        veiculo = CreateVehicle(modelo, x + 3.0, y, z, angulo, -1, -1, 600);

        if (veiculo == INVALID_VEHICLE_ID)
        {
            SendClientMessage(playerid, COR_VERMELHO, "Nao foi possivel criar o veiculo.");
            return 1;
        }

        gCombustivel[veiculo] = 100.0;
        PutPlayerInVehicle(playerid, veiculo, 0);

        SendClientMessage(playerid, COR_VERDE, "Veiculo criado.");
        return 1;
    }

    if (!strcmp(cmd, "/skin", true))
    {
        valor = strval(arg1);

        if (arg1[0] == EOS || valor < 0 || valor > 311)
        {
            SendClientMessage(playerid, COR_AMARELO, "Uso correto: /skin [id 0-311]");
            return 1;
        }

        gSkin[playerid] = valor;
        SetPlayerSkin(playerid, valor);
        SalvarConta(playerid);

        SendClientMessage(playerid, COR_VERDE, "Skin alterada.");
        return 1;
    }

    if (!strcmp(cmd, "/pagar", true))
    {
        if (arg1[0] == EOS || arg2[0] == EOS)
        {
            SendClientMessage(playerid, COR_AMARELO, "Uso correto: /pagar [id] [valor]");
            return 1;
        }

        alvo = strval(arg1);
        valor = strval(arg2);

        if (!JogadorValido(alvo) || gEstado[alvo] != ESTADO_LOGADO)
        {
            SendClientMessage(playerid, COR_VERMELHO, "Jogador invalido.");
            return 1;
        }

        if (alvo == playerid)
        {
            SendClientMessage(playerid, COR_VERMELHO, "Voce nao pode pagar a si mesmo.");
            return 1;
        }

        if (valor <= 0 || valor > gDinheiro[playerid])
        {
            SendClientMessage(playerid, COR_VERMELHO, "Valor invalido ou saldo insuficiente.");
            return 1;
        }

        AdicionarDinheiro(playerid, -valor);
        AdicionarDinheiro(alvo, valor);

        GetPlayerName(alvo, nomeAlvo, sizeof nomeAlvo);
        format(mensagem, sizeof mensagem, "Voce pagou R$ %d para %s.", valor, nomeAlvo);
        SendClientMessage(playerid, COR_VERDE, mensagem);

        GetPlayerName(playerid, nomeAlvo, sizeof nomeAlvo);
        format(mensagem, sizeof mensagem, "Voce recebeu R$ %d de %s.", valor, nomeAlvo);
        SendClientMessage(alvo, COR_VERDE, mensagem);

        SalvarConta(playerid);
        SalvarConta(alvo);
        return 1;
    }

    if (!strcmp(cmd, "/tp", true))
    {
        local = -1;

        if (!strcmp(arg1, "centro", true))
        {
            local = 0;
        }
        else if (!strcmp(arg1, "hospital", true))
        {
            local = 1;
        }
        else if (!strcmp(arg1, "delegacia", true))
        {
            local = 2;
        }
        else if (!strcmp(arg1, "oficina", true))
        {
            local = 3;
        }
        else if (!strcmp(arg1, "praia", true))
        {
            local = 4;
        }

        if (local == -1)
        {
            SendClientMessage(playerid, COR_AMARELO, "Uso: /tp [centro/hospital/delegacia/oficina/praia]");
            return 1;
        }

        SetPlayerPos(playerid, gLocais[local][0], gLocais[local][1], gLocais[local][2]);
        SetPlayerFacingAngle(playerid, gLocais[local][3]);

        SendClientMessage(playerid, COR_VERDE, "Teleportado.");
        return 1;
    }

    /* ---------------- comandos de admin ---------------- */

    if (!strcmp(cmd, "/kick", true))
    {
        if (gAdmin[playerid] < 1)
        {
            SendClientMessage(playerid, COR_VERMELHO, "Sem permissao.");
            return 1;
        }

        alvo = strval(arg1);

        if (arg1[0] == EOS || !JogadorValido(alvo))
        {
            SendClientMessage(playerid, COR_AMARELO, "Uso correto: /kick [id]");
            return 1;
        }

        GetPlayerName(alvo, nomeAlvo, sizeof nomeAlvo);
        format(mensagem, sizeof mensagem, "Voce expulsou %s.", nomeAlvo);
        SendClientMessage(playerid, COR_VERDE, mensagem);

        SendClientMessage(alvo, COR_VERMELHO, "Voce foi expulso por um administrador.");
        Kick(alvo);
        return 1;
    }

    if (!strcmp(cmd, "/ban", true))
    {
        if (gAdmin[playerid] < 2)
        {
            SendClientMessage(playerid, COR_VERMELHO, "Sem permissao.");
            return 1;
        }

        alvo = strval(arg1);

        if (arg1[0] == EOS || !JogadorValido(alvo))
        {
            SendClientMessage(playerid, COR_AMARELO, "Uso correto: /ban [id]");
            return 1;
        }

        gBanido[alvo] = 1;
        SalvarConta(alvo);

        GetPlayerName(alvo, nomeAlvo, sizeof nomeAlvo);
        format(mensagem, sizeof mensagem, "Voce baniu %s.", nomeAlvo);
        SendClientMessage(playerid, COR_VERDE, mensagem);

        SendClientMessage(alvo, COR_VERMELHO, "Voce foi banido.");
        BanEx(alvo, "Banido por administrador");
        return 1;
    }

    if (!strcmp(cmd, "/irpara", true))
    {
        if (gAdmin[playerid] < 1)
        {
            SendClientMessage(playerid, COR_VERMELHO, "Sem permissao.");
            return 1;
        }

        alvo = strval(arg1);

        if (arg1[0] == EOS || !JogadorValido(alvo))
        {
            SendClientMessage(playerid, COR_AMARELO, "Uso correto: /irpara [id]");
            return 1;
        }

        GetPlayerPos(alvo, x, y, z);
        SetPlayerPos(playerid, x + 1.0, y, z);

        SendClientMessage(playerid, COR_VERDE, "Teleportado ate o jogador.");
        return 1;
    }

    if (!strcmp(cmd, "/trazer", true))
    {
        if (gAdmin[playerid] < 1)
        {
            SendClientMessage(playerid, COR_VERMELHO, "Sem permissao.");
            return 1;
        }

        alvo = strval(arg1);

        if (arg1[0] == EOS || !JogadorValido(alvo))
        {
            SendClientMessage(playerid, COR_AMARELO, "Uso correto: /trazer [id]");
            return 1;
        }

        GetPlayerPos(playerid, x, y, z);
        SetPlayerPos(alvo, x + 1.0, y, z);

        SendClientMessage(playerid, COR_VERDE, "Jogador trazido ate voce.");
        SendClientMessage(alvo, COR_AMARELO, "Voce foi trazido por um administrador.");
        return 1;
    }

    if (!strcmp(cmd, "/setdinheiro", true))
    {
        if (gAdmin[playerid] < 3)
        {
            SendClientMessage(playerid, COR_VERMELHO, "Sem permissao.");
            return 1;
        }

        alvo = strval(arg1);
        valor = strval(arg2);

        if (arg1[0] == EOS || arg2[0] == EOS || !JogadorValido(alvo) || valor < 0)
        {
            SendClientMessage(playerid, COR_AMARELO, "Uso correto: /setdinheiro [id] [valor]");
            return 1;
        }

        DefinirDinheiro(alvo, valor);
        SalvarConta(alvo);

        GetPlayerName(alvo, nomeAlvo, sizeof nomeAlvo);
        format(mensagem, sizeof mensagem, "Dinheiro de %s definido para R$ %d.", nomeAlvo, valor);
        SendClientMessage(playerid, COR_VERDE, mensagem);

        SendClientMessage(alvo, COR_AMARELO, "Seu dinheiro foi alterado por um administrador.");
        return 1;
    }

    SendClientMessage(playerid, COR_CINZA, "Comando desconhecido. Use /ajuda.");
    return 1;
}
