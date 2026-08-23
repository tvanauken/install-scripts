with open('houston-ui/install.sh', 'r') as file:
    content = file.read()

content = content.replace('"S45" "Storinator S45 (45 Drives)" \\', '"S45" "Storinator S45 Turbo (45 Drives)" \\')

with open('houston-ui/install.sh', 'w') as file:
    file.write(content)
