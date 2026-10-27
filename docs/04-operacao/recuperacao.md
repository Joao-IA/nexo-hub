# Recuperação manual

**Status:** vigente (procedimentos válidos desde já, com ou sem o Nexo instalado).

Use esta página quando o mouse perdeu as personalizações, o logid não sobe ou você quer desfazer tudo
sem depender da interface. Todos os comandos rodam num terminal; os que começam com `sudo` pedem senha.

## 1. Diagnóstico rápido (30 segundos)

```bash
systemctl status logid --no-pager          # "active (running)"?
journalctl -u logid -n 30 --no-pager       # procure "Parse error", "ERROR", "Device found"
```

- `Parse error in /etc/logid.cfg, line N` → o arquivo tem erro de sintaxe. Vá para o passo 2.
- `active (running)` mas sem `Device found` → o mouse não foi detectado. Vá para o passo 4.
- Serviço `inactive` sem erro → `sudo systemctl start logid`.

## 2. Voltar para um backup

### 2.1 Backups feitos pelo Nexo (a partir da Fase 3)

```bash
sudo ls -lt /var/lib/nexo/backups/
# original-*.cfg      → sua config antes do Nexo existir (nunca é apagado)
# AAAAMMDD-HHMMSS-*.cfg → uma cópia antes de cada "Aplicar"

sudo install -m 0644 -o root -g root /var/lib/nexo/backups/<arquivo>.cfg /etc/logid.cfg
sudo systemctl restart logid
journalctl -u logid -n 10 --no-pager       # deve mostrar "Device found: MX Master 3S"
```

### 2.2 Config original do repositório

O repositório guarda uma cópia da sua configuração de 27/10/2026:
[`fixtures/logid/user-original-2026-10-27.cfg`](../../fixtures/logid/user-original-2026-10-27.cfg).

```bash
sudo install -m 0644 -o root -g root \
     ~/Documentos/VSCode/Git/logiOpsPlus/fixtures/logid/user-original-2026-10-27.cfg /etc/logid.cfg
sudo systemctl restart logid
```

### 2.3 Config mínima garantida (emergência)

Se nada mais funcionar, este arquivo é válido e deixa o mouse com comportamento padrão + DPI 1600:

```bash
printf 'devices: ({ name: "MX Master 3S"; dpi: 1600; });\n' | sudo tee /etc/logid.cfg >/dev/null
sudo systemctl restart logid
```

## 3. Validar um arquivo antes de aplicar (sem o Nexo)

O logid não tem modo "só validar". Teste num processo separado, com o serviço parado:

```bash
sudo systemctl stop logid
sudo logid -v -c /caminho/teste.cfg        # Ctrl+C para sair; observe erros e "Device found"
sudo systemctl start logid
```

## 4. Mouse não detectado (Bluetooth)

```bash
bluetoothctl info D5:C1:47:E4:17:05 | grep -E "Connected|Name"   # conectado?
ls -l /dev/hidraw*                                               # existe um para o mouse?
sudo systemctl restart logid                                     # força nova detecção
```

No boot é normal aparecer `Failed to add device /dev/hidraw2 after 5 tries` (o Bluetooth ainda não está
pronto). A regra `/etc/udev/rules.d/99-logid.rules` reinicia o logid quando o mouse reconecta — confira
se ela existe:

```bash
cat /etc/udev/rules.d/99-logid.rules
# ACTION=="add", SUBSYSTEM=="hidraw", KERNELS=="0005:046D:B034*", RUN+="/bin/systemctl --no-block restart logid.service"
```

## 5. Desinstalar o Nexo e deixar o sistema limpo (a partir da Fase 7)

```bash
sudo apt remove nexo          # remove programa; mantém /var/lib/nexo (backups)
sudo apt purge nexo           # remove também /var/lib/nexo
```

O `/etc/logid.cfg` **não é apagado** na desinstalação: ele continua com a última configuração aplicada.
Para voltar à config de antes do Nexo, use o `original-*.cfg` (passo 2.1) **antes** do `purge`.
