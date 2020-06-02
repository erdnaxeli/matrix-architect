all:
	crystal build src/matrix-architect.cr

run:
	crystal run src/matrix-architect.cr

static:
	crystal build --static src/matrix-architect.cr
