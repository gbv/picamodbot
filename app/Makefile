deps:
	@carton install

test:
	@./test

debuild: clean deps
	@dzil debuild --uc --us

cover:
	@cover -delete
	@carton exec -- find t -iname "*.t" -exec perl -MDevel::Cover=+inc,local,+ignore,t -Ilib '{}' ';'
	@cover --summary

doc:
	@cd doc; make html pdf

run:
	@./start -d

clean:
	@rm -rf cover_db debuild cache

.PHONY: deps test run debuild cover doc clean
