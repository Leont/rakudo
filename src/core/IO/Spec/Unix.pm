my class IO::Spec::Unix is IO::Spec does IO::Spec::Any {

    method canonpath( $patharg, :$parent --> Str) {
        my $path = $patharg.Str;
        return '' if $path eq '';

        $path ~~ s:g { '//' '/'* }         = '/';     # xx////xx  -> xx/xx
        $path ~~ s:g { '/.'+ ['/' | $] }   = '/';     # xx/././xx -> xx/xx
        $path ~~ s { ^ './' <!before $> }  = '';      # ./xx      -> xx
        if $parent {
            Nil while $path ~~ s:g {  [^ | <?after '/'>] <!before '../'> <-[/]>+ '/..' ['/' | $ ] } = '';
            $path = '.' if $path eq '';
        }
        $path ~~ s { ^ '/..'+ ['/' | $] }  = '/';     # /../..(/xx) -> /(xx)
        unless $path eq "/" {
            $path ~~ s { '/' $ }       = '';      # xx/       -> xx    :)
        }
        $path
    }

    method dir-sep  {  '/' }
    method rootdir  { '/' }
    method devnull  { '/dev/null' }

    method basename(\path) {
        my str $str = nqp::unbox_s(path);
        my int $index = nqp::rindex($str,'/');
        nqp::p6bool($index == -1)
          ?? path
          !! substr(path,nqp::box_i($index + 1,Int) );
    }

    method tmpdir {
        my $io;
        first( {
            if .defined {
                $io = .IO;
                $io.d && $io.r && $io.w && $io.x;
            }
          },
          %*ENV<TMPDIR>,
          '/tmp',
        ) ?? $io !! IO::Path.new(".");
    }

    method is-absolute( $file ) {
        substr( $file, 0, 1 ) eq '/';
    }

    method path {
        if %*ENV<PATH> -> $PATH {
            $PATH.split( ':' ).map: { $_ || '.' };
        }
        else {
            ();
        }
    }

    method splitpath( $path, :$nofile = False ) {
        if $nofile {
            ( '', $path, '' );
        }
        else {
            $path ~~ m/^ ( [ .* \/ [ '.'**1..2 $ ]? ]? ) (<-[\/]>*) /;
            ( '', ~$0, ~$1 );
        }
    }

    method split (Cool:D $path is copy ) {
        $path  ~~ s/<?after .> '/'+ $ //;

        $path  ~~ m/^ ( [ .* \/ ]? ) (<-[\/]>*) /;
        my ($dirname, $basename) = ~$0, ~$1;

        $dirname ~~ s/<?after .> '/'+ $ //; #/

        if $basename eq '' {
            $basename = '/'  if $dirname eq '/';
        }
        else {
            $dirname = '.'  if $dirname eq '';
        }
        # shell dirname '' produces '.', but we don't because it's probably user error

        # temporary, for the transition period
        (:volume(''), :$dirname, :$basename, :directory($dirname));
#        (:volume(''), :$dirname, :$basename);
    }


    method join ($, $dirname, $file) {
        self.catpath(
          '',
          ($dirname eq '/' && $file eq '/' or $dirname eq '.' && $file.chars)
            ?? '' !! $dirname,
          $file,
        );
    }

    method catpath( $, $dirname, $file ) {
        $dirname ne ''
          && $file ne ''
          && substr($dirname, *-1 ) ne '/'
          && substr($file, 0, 1 )   ne '/'
          ?? $dirname ~ '/' ~ $file
          !! $dirname ~ $file
    }

    method catdir( *@parts ) { self.canonpath( (flat @parts, '').join('/') ) }
    method splitdir( $path ) { $path.split( '/' )  }
    method catfile( |c )     { self.catdir(|c) }

    method rel2abs( $path, $base? is copy) {
        return self.canonpath($path) if self.is-absolute($path);

        my $cwd := $*CWD;
        if !self.is-absolute( $base //= $cwd ) {
            $base = self.rel2abs( $base, $cwd ) unless $base eq $cwd;
        }
        self.catdir( self.canonpath($base), $path );
    }
}

# vim: ft=perl6 expandtab sw=4
