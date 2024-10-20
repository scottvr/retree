# eert - inverse tree utility

This tool essentially inverts what /usr/bin/tree -F does. It creates a real directory structure on your filesystem based on an ascii line-art tree. 

### There is a Python tool that takes stdin and does the needful. for example 
```bash
cd python
tree -F /home/user/example | python eert.py
# or from a file copied from a chat, document, etc
python eert.py <  example_tree.txt 
```

### There is a vscode extension that takes highlighted tree-format text, and creates a copy of the directory structure represented by it
see the eert-vscx/ subdirectort,