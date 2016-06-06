#!/bin/bash

update-alternatives --install "/usr/bin/java" "java" "/usr/java/latest/bin/java" 1 && \
update-alternatives --install "/usr/bin/javac" "javac" "/usr/java/latest/bin/javac" 1 && \
update-alternatives --install "/usr/bin/javaws" "javaws" "/usr/java/latest/bin/javaws" 1 && \
update-alternatives --set java /usr/java/latest/bin/java && \
update-alternatives --set javac /usr/java/latest/bin/javac && \
update-alternatives --set javaws /usr/java/latest/bin/javaws

