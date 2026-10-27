# Fluxos

**Status:** planejado. Cada diagrama vira `vigente` quando o fluxo for implementado e testado; ao
depurar, compare o log real com estes passos (os logs usam o mesmo **ID de correlação** em todos os
componentes — ver [logs-e-diagnostico.md](../04-operacao/logs-e-diagnostico.md)).

## 1. Aplicar configuração (com rollback)

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant UI as nexo (UI)
    participant HP as nexo-helper (root)
    participant PK as polkit
    participant FS as /etc/logid.cfg
    participant SD as systemd
    participant LD as logid

    U->>UI: Clica "Aplicar"
    UI->>UI: Valida modelo e gera texto (serializer)
    UI->>HP: ApplyConfig(texto, sha256 do arquivo lido)
    HP->>PK: Autorizado para apply-config? (ou cache da sessão)
    PK-->>HP: sim (pode ter pedido senha)
    HP->>HP: Revalida texto (mesmo validador)
    HP->>FS: sha256 atual == esperado?
    alt arquivo mudou por fora
        HP-->>UI: Erro CONFLICT (UI mostra diff e pede decisão)
    end
    HP->>HP: Copia arquivo atual para /var/lib/nexo/backups/
    HP->>FS: Grava temp + fsync + rename (atômico)
    HP->>SD: RestartUnit(logid.service)
    HP->>SD: Aguarda "active" (até 5 s)
    HP->>HP: Lê journal do logid desde o restart
    alt logid ativo e sem "Parse error"/ERROR
        HP-->>UI: OK (id do backup)
    else falhou
        HP->>FS: Restaura backup (atômico)
        HP->>SD: RestartUnit(logid.service)
        HP-->>UI: Erro APPLY_FAILED + trecho do log (rollback feito)
    end
```

## 2. Autenticação com cache por sessão

```mermaid
sequenceDiagram
    autonumber
    participant C as Chamador (UI)
    participant HP as nexo-helper
    participant DB as D-Bus daemon
    participant LG as logind
    participant PK as polkit

    C->>HP: Método que exige apply-config
    HP->>DB: GetConnectionUnixProcessID(remetente)
    HP->>LG: GetSessionByPID(pid)
    alt (uid, sessão) já no cache
        HP-->>C: segue sem perguntar
    else
        HP->>PK: CheckAuthorization(ação, permite interação)
        PK-->>C: diálogo de senha do GNOME
        PK-->>HP: autorizado
        HP->>HP: Guarda (uid, sessão) no cache
    end
    LG-->>HP: SessionRemoved(sessão)  [no logout]
    HP->>HP: Remove sessão do cache
```

## 3. Troca de perfil por aplicativo

```mermaid
sequenceDiagram
    autonumber
    participant SH as GNOME Shell + nexo-focus
    participant AG as nexo-agent
    participant HP as nexo-helper
    participant LD as logid

    SH->>AG: FocusChanged("code.desktop", "Code")
    AG->>AG: Debounce 150 ms; casa regra → perfil "codigo"
    alt perfil desejado == perfil ativo
        AG->>AG: nada a fazer
    else
        AG->>HP: SetProfile(device, "codigo")   [sem senha]
        HP->>LD: GetProfiles()  (como root)
        alt "codigo" existe
            HP->>LD: SetProfile("codigo")
            HP-->>AG: OK
        else
            HP-->>AG: Erro UNKNOWN_PROFILE (nada é alterado)
        end
    end
```

## 4. Reconexão, reinício do logid e Easy-Switch

```mermaid
sequenceDiagram
    autonumber
    participant M as Mouse
    participant UD as udev
    participant LD as logid
    participant HP as nexo-helper
    participant AG as nexo-agent

    M->>UD: Reconecta via Bluetooth (ou volta de outro PC)
    UD->>LD: (regra de reconexão) restart logid.service
    LD->>LD: Ativa default_profile
    LD-->>HP: DeviceAdded / StatusChanged(active=true)
    HP-->>AG: DeviceStatusChanged
    AG->>AG: Perfil esperado para o app em foco?
    AG->>HP: SetProfile(device, perfil esperado)
```

## 5. Detecção de dispositivos ao abrir a UI

```mermaid
sequenceDiagram
    autonumber
    participant UI as nexo (UI)
    participant SY as sysfs /sys/class/hidraw
    participant UP as UPower
    participant BZ as BlueZ
    participant HP as nexo-helper
    participant DB as device_db (JSON)

    UI->>SY: Lista dispositivos HID (vendor 046D = Logitech)
    UI->>UP: Bateria de cada um (por serial/MAC)
    UI->>BZ: Conectado? (por MAC)
    UI->>HP: ProbeDevices()  [sem senha]
    HP-->>UI: Botões, DPI, torque, perfis, perfil ativo (do logid)
    UI->>DB: Ilustração e hotspots do modelo (se conhecido)
    UI->>UI: Monta capacidades → cards e editores
```
