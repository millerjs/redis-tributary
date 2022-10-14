FROM ruby:2.7.6-alpine

WORKDIR /app

COPY Gemfile /app/Gemfile
COPY Gemfile.lock /app/Gemfile.lock
RUN bundle install

ADD . ./

CMD ruby /app/redis_tributary.rb
