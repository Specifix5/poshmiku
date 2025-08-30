# Posh Miku
my personal miku themed theme for Oh My Posh and Starship. \
based on the tokyonight_storm theme on Oh My Posh's [Repository](https://github.com/JanDeDobbeleer/oh-my-posh/blob/main/themes/tokyonight_storm.omp.json)
(and by based I mean it used to be the tokyonight_storm theme...)

## Installation
### Oh-My-Posh

PowerShell `$PROFILE`:
```powershell
oh-my-posh init pwsh --config "https://raw.githubusercontent.com/Specifix5/poshmiku/refs/heads/main/poshmiku.omp.json" | Invoke-Expression
```

### Starship
Replace your `~/.config/starship.toml` or equivalent with the one on the repo

For fish users, you can install transient prompts with (using fisher)
```bash
fisher install zzhaolei/transient.fish
```

Then replace `~/.config/fish/functions/__fish_prompt.fish` with the one on the repo.

## Preview
![image](https://github.com/user-attachments/assets/adaf988c-a455-4ba4-8cad-b528efe6ec49)
![image](https://github.com/user-attachments/assets/dfa779c5-d6a0-4fe8-872f-d8d1241ab420)
