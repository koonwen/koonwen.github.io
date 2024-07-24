setup_debian:
# Install ruby and jekyll, https://jekyllrb.com/docs/installation/other-linux/
	sudo apt-get install ruby-full build-essential rbenv
	bundle3.1 config set --local path 'vendor/bundle'
	bundle3.1 install

serve:
	bundle3.1 exec jekyll serve --livereload

serve_all:
	bundle3.1 exec jekyll serve --drafts --unpublished --livereload
