// Our browser check code. Will be stripped of comments like this one.
//
// TODO: obfuscate this with a python program or something like that
//
//  take a value from LUA code
//  pick some random nonce to go with that
//  add as a temp cookie / reload same URL ... or maybe do an ajax call
//  reload same URL
//  wait for drama somewhere
//

function die_now(msg) {
	$('.js-main').replaceWith('<pre>\n\n' + msg);
	
	throw msg;
}

function mint(seed, target) {
	var idx = 0;
	for(idx=0; idx<100000; idx++) {
		var m = seed + '.' + idx;
		var here = CryptoJS.SHA1(m).toString(), score = 0;
		if(here.indexOf(target) != -1) {
			return { "seed": seed, "pow": idx.toString(), "target": target };
		}
	}

	die_now("Please reload page to start over.");
}

$(function() {
	window.setTimeout(function() {
		var resp = mint(SEED, TARGET);
		
		$.ajax({type: "GET", url: "/___", data: resp}).done(function(data) {
			window.location.replace(data || window.location.href);
		})
		.fail(function() {
			die_now("You are blocked from this site.");
		});
	}, 500);

	window.setTimeout(function() {
		die_now("You have been blocked from this site.");
	}, 5000);
});


