package T;
use strict;
use warnings;

our $VERSION = '0.001';

use Scalar::Util();
use Test2::Util();
use Carp();
use vars qw/$AUTOLOAD/;

my %STASHES;

sub __DEFAULT_AS { 't' }
sub __DEFAULT_NS { 'Test' }

# We do not want this methods to be accessible, so we are putting it in a
# lexical variable to use internally.
my $GEN_STASH = do {
    my $GEN = 'A';
    sub { __PACKAGE__ . '::__GEN_NS_' . ($GEN++) . '__' };
};

# We do not want this methods to be accessible, so we are putting it in a
# lexical variable to use internally.
my $IMPORT = sub {
    my $proto  = shift;
    my $caller = shift;

    my (%params, @loads);
    while (my $arg = shift) {
        if (substr($arg, 0, 1) eq '-') {
            $params{$arg} = shift;
        }
        else {
            my $args = ref($_[0]) ? shift : [];
            push @loads => [$arg, @$args];
        }
    }

    my ($stash, $class, $no_scope);
    if ($class = Scalar::Util::blessed($proto)) {
        Carp::croak("Params are not allowed when using import() as an object method: " . join(', ', keys %params))
            if keys %params;

        $stash = $$proto;
        $no_scope = 1;
    }
    else {
        $class = $proto;

        my $as   = delete $params{'-as'}   || $class->__DEFAULT_AS;
        my $from = delete $params{'-from'} || $caller->[0];
        $no_scope = delete $params{'-no_scope'};

        Carp::croak("Invalid params: " . join(', ', keys %params))
            if keys %params;

        $stash = $STASHES{$from}->{$as} ||= $GEN_STASH->();
        bless(\$stash, $class) unless Scalar::Util::blessed(\$stash);

        unless ($caller->[0]->can($as)) {
            my $t = sub {
                return \$stash unless @_;

                my $meth = shift;

                my $sub = $stash->can($meth)
                    or Carp::croak("No such function: '$meth'");

                goto &$sub;
            };

            no strict 'refs';
            *{"$caller->[0]\::$as"} = $t;
        }
    }

    return unless @loads;

    my $header = qq{package $stash;\n#line $caller->[2] "$caller->[1]"};
    my $sub = $no_scope ? undef : eval qq{$header\nsub { shift\->import(\@_) };} || die $@;

    for my $set (@loads) {
        my ($mod, @args) = @$set;

        $mod = $class->__DEFAULT_NS . "::$mod" unless $mod =~ s/^\+//;
        my $file = Test2::Util::pkg_to_file($mod);
        require $file;

        if ($no_scope) {
            eval qq{$header\nBEGIN { \$mod\->import(\@args) }; 1} or die $@;
        }
        else {
            $sub->($mod, @args);
        }
    }
};

sub import {
    my $proto = shift;
    my @caller = caller(0);

    $proto->$IMPORT(\@caller, @_);
}

sub new {
    my $class = shift;
    my @caller = caller(0);

    my $stash = $GEN_STASH->();
    my $self = bless(\$stash, $class);

    $self->$IMPORT(\@caller, @_) if @_;

    return $self;
}

sub can {
    my $proto = shift;
    my $class = Scalar::Util::blessed($proto)
        or return $proto->SUPER::can(@_);

    my $stash = $$proto;
    return $stash->can(@_);
}

sub isa {
    my $proto = shift;
    return $proto->SUPER::isa(@_);
}

sub AUTOLOAD {
    my $meth = $AUTOLOAD;
    $meth =~ s/^.*:://g;

    return if $meth eq 'DESTROY';

    my $class = Scalar::Util::blessed($_[0])
        or Carp::croak(qq{Can't locate object method "$meth" via package "$_[0]"});

    # Need to shift self as the "methods" are actually functions imported into
    # the stash.
    my $self = shift @_;

    my $sub = $self->can($meth)
        or Carp::croak("No such function '$meth'");

    goto &$sub;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

T - Testing tool import encapsulation.

=head1 DESCRIPTION

=head1 SOURCE

The source code repository for T can be found at
F<http://github.com/Test-More/T/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2016 Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
