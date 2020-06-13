all:
	crystal build src/main.cr

run:
	crystal run src/main.cr

static:
	crystal build --static src/main.cr
