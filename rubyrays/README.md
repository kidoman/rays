# rubyrays

This is a Ruby port of [the business card raytracer][1].

It is a multithreaded implementation, meaning it would not be wise to
run it on MRI. Use either [Rubinius][2] or [JRuby][3].

## Usage

    $ ruby rubyrays.rb > rubyrays.ppm

There are three optional arguments: `width`, `height`, and `threads`.

[1]: https://gist.github.com/kid0m4n/6680629
[2]: http://rubini.us/
[3]: http://jruby.org/
