# 🐚 Bash & Zsh Interactive Demo

This file demonstrates how `neovim-send-to-terminal` handles **Bash**, **Zsh**, and **POSIX Shell** commands.

---

## 1. Prompt Stripping (`$ `, `❯ `, `% `, `# `)

Place cursor on the line below and press `<leader>ss`:

```bash
$ uname -a
❯ echo $SHELL
% which nvim
# id -u
```

*Expected behavior:* All prompt symbols (`$`, `❯`, `%`, `#`) are stripped cleanly.

---

## 2. Multi-Line Commands with Backslash (`\`) Continuations

Place cursor on the first line and press `<leader>ss` (or step through with `<leader>sn`):

```bash
curl -s https://api.github.com/zen \
  -H "Accept: application/vnd.github.v3+json" \
  -H "User-Agent: Neovim-Send-To-Terminal"
```

*Expected behavior:* The plugin detects the trailing backslashes and sends all 3 lines as one atomic command with bracketed paste mode, preventing accidental execution of incomplete commands.

---

## 3. Docker / Complex Multi-Line Flags

```bash
docker run -d \
  --name web-server \
  --restart always \
  -p 8080:80 \
  -e ENVIRONMENT=production \
  nginx:alpine
```

---

## 4. Documentation with Interleaved Terminal Output

Press `<leader>sb` to send the entire block below:

```bash
$ git status
On branch master
Your branch is up to date with 'origin/master'.
nothing to commit, working tree clean
$ git log -1 --oneline
f212397 feat: automatically paste commented execution outcome below commands in markdown
$ echo "Done!"
```

*Expected behavior:* The plugin strips all non-command output lines, executing only:
1. `git status`
2. `git log -1 --oneline`
3. `echo "Done!"`

---

## 5. Heredocs (`cat << 'EOF' ... EOF`)

```bash
cat << 'EOF' > /tmp/demo_config.yaml
server:
  host: 127.0.0.1
  port: 8080
  workers: 4
EOF
cat /tmp/demo_config.yaml
```

---

## 6. Step-Through Mode (`<leader>sn`)

Press `<leader>sn` repeatedly on the block below to step through each command one by one:

```bash
mkdir -p /tmp/send-demo
cd /tmp/send-demo
touch file1.txt file2.txt file3.txt
ls -la
cd -
rm -rf /tmp/send-demo
```
