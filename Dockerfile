FROM atdr.meo.ws/archiveteam/grab-base-df
COPY . /grab
RUN ln -fs /usr/local/bin/wget-lua /grab/wget-at
RUN sed -i 's|DEFAULT_RETRY_DELAY = 60$|DEFAULT_RETRY_DELAY = 0|;s|self\.retry_delay += 10|self.retry_delay += 0.1|' /usr/local/lib/python*/site-packages/seesaw/tracker.py
