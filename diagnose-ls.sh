#!/usr/bin/env bash
# Diagnostic script - run on the affected Linux machine
# Output this to me so I can identify the exact issue

echo "=== DIAGNOSTIC OUTPUT ==="
echo "Date: $(date)"
echo "User: $(whoami)"
echo "Shell: $SHELL"
echo "BASH_VERSION: $BASH_VERSION"
echo ""

echo "=== ALIAS DEFINITIONS ==="
alias 2>/dev/null | grep -E "^alias (ls|ll|la|l)="
echo ""

echo "=== TYPE LS ==="
type ls 2>&1
echo ""

echo "=== SEARCHING FOR LS ALIASES IN ALL STARTUP FILES ==="
for f in ~/.bashrc ~/.bash_profile ~/.profile /etc/bash.bashrc /etc/profile ~/.bash_aliases; do
  if [[ -f "$f" ]]; then
    echo "--- $f ---"
    grep -n "alias ls" "$f" 2>/dev/null || echo "(no ls alias found)"
  fi
done
echo ""

echo "=== KALI-PROMPT MANAGED BLOCK IN .bashrc ==="
if [[ -f ~/.bashrc ]]; then
  sed -n '/# >>> kali-prompt-install >>>/,/# <<< kali-prompt-install <<</p' ~/.bashrc
else
  echo ".bashrc not found"
fi
echo ""

echo "=== ACTUAL LS TEST ==="
mkdir -p /tmp/ls-test-$$
cd /tmp/ls-test-$$
touch file1 file2 .hidden
echo "Plain ls:"
ls
echo ""
echo "ls -la:"
ls -la
echo ""
echo "ls -A:"
ls -A
echo ""
echo "/bin/ls -la (bypassing alias):"
/bin/ls -la
rm -rf /tmp/ls-test-$$
echo ""

echo "=== END DIAGNOSTIC ==="
