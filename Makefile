JAVA_HOME = /opt/jdk1.8
CC = gcc
JAVA = java
JAVAC = javac
JAVAC_WITH_PATH = PATH=$(JAVA_HOME)/bin:$(PATH) $(JAVAC)
JAVA_WITH_PATH = PATH=$(JAVA_HOME)/bin:$(PATH) $(JAVA)
TYRUS_LIBS = websocket-ri-archive-1.9/lib
TYRUS_APIS = websocket-ri-archive-1.9/api
TYRUS_EXTS = websocket-ri-archive-1.9/ext
JLIBS = $(TYRUS_APIS)/javax.websocket-api-1.1.jar:$(TYRUS_LIBS)/tyrus-server-1.9.jar:$(TYRUS_LIBS)/tyrus-spi-1.9.jar:$(TYRUS_LIBS)/tyrus-core-1.9.jar:$(TYRUS_LIBS)/tyrus-container-grizzly-server-1.9.jar:$(TYRUS_EXTS)/grizzly-framework-2.3.15-gfa.jar:$(TYRUS_EXTS)/grizzly-http-server-2.3.15-gfa.jar:$(TYRUS_EXTS)/grizzly-http-2.3.15-gfa.jar:$(TYRUS_LIBS)/tyrus-container-grizzly-client-1.9.jar

websocketterm/ReplServer.class: websocketterm/ReplServer.java domterm.jar
	$(JAVAC) websocketterm/ReplServer.java -cp domterm.jar:$(JLIBS)

websocketterm/WebSocketServer.class: websocketterm/WebSocketServer.java
	$(JAVAC) websocketterm/WebSocketServer.java -cp .:$(JLIBS)

native/pty/org_domterm_pty_PTY.h: domterm.jar
	javah -d native/pty org.domterm.pty.PTY

PTY_COMMON_PARAMS = -fno-strict-aliasing -fPIC -W -Wall  -Wno-unused -Wno-parentheses -fno-omit-frame-pointer

native/pty/pty.o: native/pty/pty.c native/pty/org_domterm_pty_PTY.h
	$(CC) -O2 -ffast-math $(PTY_COMMON_PARAMS) -Inative/pty -I$(JAVA_HOME)/include -I$(JAVA_HOME)/include/linux -c $< -o $@

native/pty/pty_fork.o: native/pty/pty_fork.c
	$(CC) -O2 -ffast-math $(PTY_COMMON_PARAMS) -Inative/pty -I$(JAVA_HOME)/include -I$(JAVA_HOME)/include/linux -c $< -o $@

libpty.so: native/pty/pty.o native/pty/pty_fork.o
	$(CC) $(PTY_COMMON_PARAMS) -shared -o $@ $^

d/domterm: d/domterm.ti
	tic -o. $<

run-pty: libpty.so d/domterm domterm.jar
	$(JAVA_WITH_PATH) -Djava.library.path=`pwd` -jar domterm.jar --pty

EXTRA_CLASSPATH =
old-run-server: websocketterm/WebSocketServer.class websocketterm/ReplServer.class org/domterm/util/Util.class libpty.so d/domterm domterm.jar
	$(JAVA) -cp .:$(EXTRA_CLASSPATH):$(JLIBS) -Djava.library.path=`pwd` websocketterm.WebSocketServer

SERVER_ARGS =
run-server: libpty.so d/domterm domterm.jar
	$(JAVA) -cp $(EXTRA_CLASSPATH):domterm.jar:java_websocket.jar -Djava.library.path=`pwd` org.domterm.websocket.DomServer $(SERVER_ARGS)

run-shell: domterm.jar
	CLASSPATH=domterm.jar $(JAVA_WITH_PATH) org.domterm.javafx.RunProcess

clean:
	-rm -rf org/classes.stamp tmp-for-jar org/domterm/*.class org/domterm/*.*.class websocketterm/*.class libpty.so build doc/DomTerm.xml web/*.html domterm.jar tmp-repl.in native/pty/*.o native/pty/org_domterm_pty_PTY.h

DOMTERM_JAR_SOURCES = \
  org/domterm/javafx/WebTerminalApp.java \
  org/domterm/javafx/RunClass.java \
  org/domterm/javafx/RunProcess.java \
  org/domterm/javafx/WebWriter.java \
  org/domterm/javafx/WebTerminal.java \
  org/domterm/javafx/Main.java \
  org/domterm/Client.java \
  org/domterm/ClassClient.java \
  org/domterm/ProcessClient.java \
  org/domterm/util/DomTermErrorStream.java \
  org/domterm/util/StringBufferedWriter.java \
  org/domterm/util/Util.java \
  org/domterm/util/WTDebug.java \
  org/domterm/util/Utf8WriterOutputStream.java \
  org/domterm/websocket/DomServer.java \
  org/domterm/pty/PtyClient.java \
  org/domterm/pty/RunPty.java \
  org/domterm/pty/PTY.java

org/classes.stamp: $(DOMTERM_JAR_SOURCES)
	$(JAVAC_WITH_PATH) -cp .:java_websocket.jar $?
	touch org/classes.stamp

tmp-repl.in: org/domterm/repl.html Makefile
	sed -e '/domterm-core/i<style>' \
	  -e '/domterm-default/a</style>' \
	  -e 's|<link .*/style/\(.*\).css">|#include "style/\1.css"|' \
	  -e '/<script type="text.javascript">/d' \
	  -e '/domterm-default/a<script type="text/javascript">' \
	  -e 's|<script .*src=.*/\(.*\).js.*>|#include "\1.js"|' \
	  <org/domterm/repl.html >tmp-repl.in

# JavaFX seems to have a problem loading .js files referenced from repl.html,
# in a .jar, but inline javascript and css works.
# So we use cpp to inline it into one by repl.html.
# Ugly - hopefully we can figure out what is going on.
domterm.jar: org/classes.stamp terminal.js tmp-repl.in
	rm -rf tmp-for-jar
	mkdir tmp-for-jar
	tar cf - org/domterm/*.class org/domterm/*/*.class | (cd tmp-for-jar; tar xf -)
	cpp -traditional-cpp -P <tmp-repl.in >tmp-for-jar/org/domterm/repl.html
	cd tmp-for-jar && \
	  jar cmf ../domterm-jar-manifest ../domterm.jar org/domterm/*.class org/domterm/*/*.class org/domterm/repl.html 

MAKEINFO = makeinfo
srcdir = .
XSLT = xsltproc
DOCBOOK_XSL_DIR = /home/bothner/Software/docbook-xsl-1.78.1
doc/index.html: doc/DomTerm.texi
	$(MAKEINFO) -I$(srcdir) --html --no-node-files $< -o doc

DOC_IMAGES = \
  doc/images/domterm-1.png \
  doc/images/domterm-2.png \
  doc/images/emacs-in-firefox-1.png

doc/DomTerm.xml: doc/DomTerm.texi
	$(MAKEINFO) -I=doc --docbook doc/DomTerm.texi -o - | \
	sed \
	-e 's|_002d|-|g' \
	-e 's|<emphasis></emphasis>||' \
	-e 's|<inlinemediaobject><imageobject><imagedata fileref="\(.*\)" format="\(.*\)"></imagedata></imageobject></inlinemediaobject>|<ulink url="\1"><inlinemediaobject><imageobject><imagedata fileref="\1" format="\2"></imagedata></imageobject></inlinemediaobject></ulink>|' \
	-e 's|<chapter label="" id="Top">|<chapter label="Top" id="Top"><?dbhtml filename="index.html"?>|' \
	> doc/DomTerm.xml

web/index.html: doc/DomTerm.xml Makefile
	$(XSLT) --path $(DOCBOOK_XSL_DIR)/html \
	  --output web/  \
	  --stringparam root.filename toc \
	  --stringparam generate.section.toc.level 0 \
	  --stringparam chunker.output.encoding UTF-8 \
	  --stringparam chunker.output.doctype-public "-//W3C//DTD HTML 4.01 Transitional//EN" \
	  --stringparam generate.index 1 \
	  --stringparam use.id.as.filename 1 \
	  --stringparam chunker.output.indent yes \
	  --stringparam chunk.first.sections 1 \
	  --stringparam chunk.section.depth 0 \
	  --stringparam chapter.autolabel 0 \
	  --stringparam chunk.fast 1 \
	  --stringparam toc.max.depth 4 \
	  --stringparam toc.list.type ul \
	  --stringparam toc.section.depth 3 \
	  --stringparam chunk.separate.lots 1 \
	  --stringparam chunk.tocs.and.lots 1 \
	  doc/style/domterm.xsl doc/DomTerm.xml
	cp $(DOC_IMAGES) web/images

WEB_SERVER_ROOT=bothner@bothner.com:domterm.org
upload-web:
	cd web && \
	  rsync -v -r -u -l -p -t --relative . $(WEB_SERVER_ROOT)
