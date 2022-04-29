STYLESHEET=http://www.afnic.fr/tpl/tpl.css

all: afnic.fr.html afnic.en.html

afnic.fr.html: afnic.profile
	./profile2html.py -l fr -s ${STYLESHEET} afnic.profile > $@ || rm -f $@

afnic.en.html: afnic.profile
	./profile2html.py -l en -s ${STYLESHEET} afnic.profile > $@ || rm -f $@

clean:
	rm -f *.html *~