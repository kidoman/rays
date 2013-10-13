# rubyrays

This is a Ruby port of [the business card raytracer][1].

The implementation is multithreaded, but unfortunately, MRI's GIL does
not allow for thread-level parallelism. It is recommended to run on
either [Rubinius][2] or [JRuby][3], which is an alternative Ruby
implentation that does support real threading.

## Prerequisites

  * Ruby 1.9+
  * JRuby 1.7.5

## Usage

    $ ruby rubyrays.rb
    $ jruby -J-server -J-Xms4096m -J-Xmx8192m -J-XX:+AggressiveOpts rubyrays.rb
    $ open render.ppm

There are three optional arguments: `width`, `height`, and `threads`.

[1]: https://gist.github.com/kid0m4n/6680629
[2]: http://rubini.us/
[3]: http://jruby.org/
