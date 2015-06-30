package RoboBot::Config;

use namespace::autoclean;

use Moose;
use MooseX::SetOnce;

use Config::Any::Merge;
use DBIx::DataStore ( config => 'yaml' );
use File::HomeDir;

use RoboBot::NetworkFactory;
use RoboBot::Channel;
use RoboBot::Nick;

has 'bot' => (
    is       => 'ro',
    isa      => 'RoboBot',
    required => 1,
);

has 'config_paths' => (
    is        => 'rw',
    isa       => 'ArrayRef[Str]',
    traits    => [qw( SetOnce )],
    predicate => 'has_config_paths',
);

has 'config' => (
    is  => 'rw',
    isa => 'HashRef',
);

has 'networks' => (
    is  => 'rw',
    isa => 'HashRef',
);

has 'channels' => (
    is  => 'rw',
    isa => 'ArrayRef[RoboBot::Channel]',
);

has 'db' => (
    is => 'rw',
    isa => 'DBIx::DataStore',
    traits => [qw( SetOnce )],
);

sub load_config {
    my ($self) = @_;

    $self->locate_config unless $self->has_config_paths;

    if (my $cfg = Config::Any::Merge->load_files({ files => $self->config_paths, use_ext => 1, override => 1 })) {
        $self->config($cfg);

        $self->validate_database;
        $self->validate_globals;
        $self->validate_networks;

        $self->bot->networks([ values %{$self->networks} ]);
    } else {
        die "Could not load configuration files: " . join(', ', @{$self->config_paths});
    }
}

sub locate_config {
    my ($self) = @_;

    my $home = File::HomeDir->my_home();
    my @exts = qw( conf yml yaml json xml ini );
    my @bases = ("$home/.lispy/lispy.", "$home/.lispy.", "/etc/lispy.");

    my @configs;

    foreach my $base (@bases) {
        foreach my $ext (@exts) {
            push(@configs, $base . $ext);
        }
    }

    my @found;

    CONFIG_FILE:
    foreach my $path (@configs) {
        if (-f $path && -r _) {
            push(@found, $path);
        }
    }

    $self->config_paths([reverse @found]);

    die "Unable to locate a configuration file!" unless $self->has_config_paths;
}

sub validate_globals {
    my ($self) = @_;

    my %global = (
        nick => 'lispy',
    );

    $self->config->{'global'} = \%global unless exists $self->config->{'global'};

    foreach my $k (keys %global) {
        $self->config->{'global'}{$k} = $global{$k} unless exists $self->config->{'global'}{$k};
    }

    $self->config->{'global'}{'nick'} = RoboBot::Nick->new(
        config => $self,
        name   => $self->config->{'global'}{'nick'}
    );
}

sub validate_database {
    my ($self) = @_;

    my %database = (
        name => 'robobot',
    );

    $self->config->{'database'} = \%database unless exists $self->config->{'database'};

    foreach my $k (keys %database) {
        $self->config->{'database'}{$k} = $database{$k} unless exists $self->config->{'database'}{$k};
    }

    $self->db(DBIx::DataStore->new($self->config->{'database'}{'name'})) or die "Could not validate database connection!";
}

sub validate_networks {
    my ($self) = @_;

    my @networks;
    my @channels;

    my $nfactory = RoboBot::NetworkFactory->new(
        bot    => $self->bot,
        config => $self,
        nick   => $self->config->{'global'}{'nick'},
    );

    foreach my $network_name (keys %{$self->config->{'network'}}) {
        my $net_cfg = $self->config->{'network'}{$network_name};

        push(@networks, $nfactory->create($network_name, $net_cfg));

        my @network_channels;

        # Coerce channel list into an arrayref if only a single channel is
        # listed for this network.
        $net_cfg->{'channel'} = [] unless exists $net_cfg->{'channel'};
        $net_cfg->{'channel'} = [$net_cfg->{'channel'}] if ref($net_cfg->{'channel'}) ne 'ARRAY';

        foreach my $chan_name (@{$net_cfg->{'channel'}}) {
            push(@network_channels, RoboBot::Channel->new( config => $self, network => $networks[-1], name => $chan_name));
            push(@channels, $network_channels[-1]);
        }

        $networks[-1]->channels([@network_channels]);
    }

    $self->networks({ map { $_->name => $_ } @networks });
    $self->channels(\@channels);
}

__PACKAGE__->meta->make_immutable;

1;
