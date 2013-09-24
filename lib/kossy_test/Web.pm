package kossy_test::Web;

use strict;
use warnings;
use utf8;
use Kossy;
use DBIx::Sunny;
use DBD::mysql;
use Teng;
use Teng::Schema::Loader;

my $dsn = "dbi:mysql:database=kossy_test;host=localhost";
my $user = "kossy";
my $password = "kossy_test";


filter 'set_title' => sub {
    my $app = shift;
    sub {
        my ( $self, $c )  = @_;
        $c->stash->{site_name} = __PACKAGE__;
        $app->($self,$c);
    }
};

get '/' => [qw/set_title/] => sub {
    my ( $self, $c )  = @_;
    my $dbh = DBIx::Sunny->connect($dsn, $user, $password);
    my $teng = Teng::Schema::Loader->load(
      'dbh'       => $dbh,
      'namespace' => 'KossyTest::DB',
    );
    my $iter = $teng->search('test', {}, +{limit => 10, order_by => 'id desc'});
    $c->render('index.tx', { status => 'alert-info', message => "何かテキストを入力してください", results => $iter });
};

post '/' => sub {
    my ( $self, $c )  = @_;
    # validation
    my $result = $c->req->validator([
        'msg' => {
            rule => [
                ['NOT_NULL', 'empty body'],
            ],
        },
    ]);

    my $dbh = DBIx::Sunny->connect($dsn, $user, $password);
    my $teng = Teng::Schema::Loader->load(
        'dbh'       => $dbh,
        'namespace' => 'KossyTest::DB',
    );

    # error check
    if ( $result->has_error ){
        my $iter = $teng->search('test', {}, +{limit => 10, order_by => 'id desc'});
        $c->render('index.tx', { status => "alert-error", message => "テキストが入力されていません", results => $iter } );
    } else{
        my $insert_result = $teng->insert('test' => {
            'msg' => $result->valid('msg')
        });
        my $iter = $teng->search('test', {}, +{limit => 10, order_by => 'id desc'});
        $c->render('index.tx', { status => "alert-success", message => "テキストを保存しました", results => $iter });
    }
    #my $dbh = DBIx::Sunny->connect($dsn, $user, $password);
    #my $teng = Teng::Schema::Loader->load(
    #    'dbh' => $dbh,
    #    'namespace' => 'MyApp::DB',
    #);
};


#get '/json' => sub {
#    my ( $self, $c )  = @_;
#    my $result = $c->req->validator([
#        'q' => {
#            default => 'Hello',
#            rule => [
#                [['CHOICE',qw/Hello Bye/],'Hello or Bye']
#            ],
#        }
#    ]);
#    $c->render_json({ greeting => $result->valid->get('q') });
#};

1;

