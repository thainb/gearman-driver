package Gearman::Driver::Console;

use Moose;
use POE qw(Component::Server::TCP);
use Try::Tiny;

=head1 NAME

Gearman::Driver::Console - Management console

=head1 SYNOPSIS

    $ ~/Gearman-Driver$ ./examples/driver.pl --console_port 12345 &
    [1] 32890
    $ ~/Gearman-Driver$ telnet localhost 12345
    Trying ::1...
    telnet: connect to address ::1: Connection refused
    Trying fe80::1...
    telnet: connect to address fe80::1: Connection refused
    Trying 127.0.0.1...
    Connected to localhost.
    Escape character is '^]'.
    status
    GDExamples::Sleeper::ZzZzZzzz   3       6       3
    GDExamples::Sleeper::long_running_ZzZzZzzz      1       2       1
    GDExamples::WWW::is_online      0       1       0
    .

=head1 DESCRIPTION

By default L<Gearman::Driver> opens a management console which can
be used with a standard telnet client. It's possible to list all
running worker processes as well as changing min/max processes
on runtime.

Each successful L<command|/COMMANDS> ends with a colon. If a
command throws an error, a line starting with 'ERR' will be
returned.

=cut

has 'port' => (
    is       => 'rw',
    isa      => 'Int',
    required => 1,
);

has 'server' => (
    is  => 'ro',
    isa => 'POE::Component::Server::TCP',
);

has 'driver' => (
    handles  => { log => 'log' },
    is       => 'rw',
    isa      => 'Gearman::Driver',
    required => 1,
    weak_ref => 1,
);

sub BUILD {
    my ($self) = @_;

    $self->{server} = POE::Component::Server::TCP->new(
        Alias       => "server",
        Port        => $self->port,
        ClientInput => sub {
            my ( $session, $heap, $input ) = @_[ SESSION, HEAP, ARG0 ];
            my ( $command, @params ) = split /\s+/, $input;
            if ( $self->can($command) ) {
                try {
                    my @result = $self->$command(@params);
                    $heap->{client}->put($_) for @result;
                    $heap->{client}->put('.');
                }
                catch {
                    chomp($_);
                    $heap->{client}->put($_);
                };
            }
            elsif ($command eq 'quit') {
            }
            else {
                $heap->{client}->put("ERR unknown_command: $command");
            }
        }
    );
}

=head1 COMMANDS

=head2 status

Parameters: C<none>

    GDExamples::Sleeper::ZzZzZzzz   3       6       3
    GDExamples::Sleeper::long_running_ZzZzZzzz      1       2       1
    GDExamples::WWW::is_online      0       1       0
    .

Columns are separated by tabs in this order:

=over 4

=item * job_name

=item * min_childs

=item * max_childs

=item * current_childs

=back

=cut

sub status {
    my ($self) = @_;
    my @result = ();
    foreach my $job ( $self->driver->get_jobs ) {
        push @result, sprintf( "%s\t%d\t%d\t%d", $job->name, $job->min_childs, $job->max_childs, $job->count_childs );
    }
    return @result;
}

=head2 set_min_childs

Parameters: C<job_name min_childs>

    set_min_childs asdf 5
    ERR invalid_job_name: asdf
    set_min_childs GDExamples::Sleeper::ZzZzZzzz ten
    ERR invalid_value: min_childs must be >= 0
    set_min_childs GDExamples::Sleeper::ZzZzZzzz 10
    ERR invalid_value: min_childs must be smaller than max_childs
    set_min_childs GDExamples::Sleeper::ZzZzZzzz 5
    OK
    .

=cut

sub set_min_childs {
    my ( $self, $job_name, $min_childs ) = @_;

    my $job = $self->_get_job($job_name);

    if ( !defined($min_childs) or $min_childs !~ /^\d+$/ or $min_childs < 0 ) {
        die "ERR invalid_value: min_childs must be >= 0\n";
    }

    if ( $min_childs > $job->max_childs ) {
        die "ERR invalid_value: min_childs must be smaller than max_childs\n";
    }

    $job->min_childs($min_childs);

    return "OK";
}

=head2 set_max_childs

Parameters: C<job_name max_childs>

    set_max_childs asdf 5
    ERR invalid_job_name: asdf
    set_max_childs GDExamples::Sleeper::ZzZzZzzz ten
    ERR invalid_value: max_childs must be >= 0
    set_max_childs GDExamples::Sleeper::ZzZzZzzz 0
    ERR invalid_value: max_childs must be greater than min_childs
    set_max_childs GDExamples::Sleeper::ZzZzZzzz 6
    OK
    .

=cut

sub set_max_childs {
    my ( $self, $job_name, $max_childs ) = @_;

    my $job = $self->_get_job($job_name);

    if ( !defined($max_childs) or $max_childs !~ /^\d+$/ or $max_childs < 0 ) {
        die "ERR invalid_value: max_childs must be >= 0\n";
    }

    if ( $max_childs < $job->min_childs ) {
        die "ERR invalid_value: max_childs must be greater than min_childs\n";
    }

    $job->max_childs($max_childs);

    return "OK";
}

=head2 quit

Parameters: C<none>

Closes your connection gracefully.

=cut

sub _get_job {
    my ( $self, $job_name ) = @_;
    return $self->driver->get_job($job_name) || die "ERR invalid_job_name: $job_name\n";
}

no Moose;

__PACKAGE__->meta->make_immutable;

=head1 AUTHOR

Johannes Plunien E<lt>plu@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Johannes Plunien

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=over 4

=item * L<Gearman::Driver>

=item * L<Gearman::Driver::Job>

=item * L<Gearman::Driver::Observer>

=item * L<Gearman::Driver::Worker>

=back

=cut

1;