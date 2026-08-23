with open('houston-ui/install.sh', 'r') as f:
    content = f.read()

content = content.replace('"\\\\$@"', '"$@"')

with open('houston-ui/install.sh', 'w') as f:
    f.write(content)
