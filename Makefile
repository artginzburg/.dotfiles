install:
	stow .

brew-backup:
# TODO make this run automatically
	brew bundle dump --describe
