all:
	crystal build src/main.cr -o matrix-architect

run:
	crystal run src/main.cr

static:
	crystal build --static src/main.cr
