FROM atdr.meo.ws/archiveteam/grab-base-df
COPY . /grab
RUN ln -fs /usr/local/bin/wget-lua /grab/wget-at
