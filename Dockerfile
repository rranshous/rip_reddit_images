FROM ruby:2.7.2

RUN mkdir /data
RUN mkdir /app
WORKDIR /app
COPY ./Gemfile /app/
RUN bundle

COPY ./* /app/

ENV OUTPUT_DIR '/data/'

ENTRYPOINT ["bash"]
CMD ["download_many.sh"]
