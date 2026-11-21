-- Luau² V3 (Texere²) third-party & MIT notices.
return table.freeze({
  distribution = "Luau² V3 (Texere²)",
  primaryLicense = "MIT",
  sourceAvailability = "Keep the readable src tree and distribution manifest with this model.",
  components = table.freeze({
    table.freeze({ name = "Luau² interpreter and C++ bridges", license = "MIT", text = "notices/LuauSquared-MIT.txt" }),
    table.freeze({ name = "Texere²-generated scaffolding, runtime and Emscripten adapter", license = "MIT", text = "notices/Texere-MIT.txt" }),
    table.freeze({ name = "Pinned Luau compiler, numerics, bytecode definitions and lstrlib adaptation", license = "MIT", text = "notices/Luau-MIT.txt, notices/Lua-MIT.txt" }),
    table.freeze({ name = "Linked Emscripten system code", license = "MIT OR NCSA", text = "notices/Emscripten-MIT-NCSA.txt, notices/Emscripten-AUTHORS.txt" }),
    table.freeze({ name = "Linked LLVM libc++, libc++abi and compiler-rt", license = "Apache-2.0 WITH LLVM-exception", text = "notices/LLVM-libcxx.txt, notices/LLVM-libcxxabi.txt, notices/LLVM-compiler-rt.txt" }),
    table.freeze({ name = "Linked musl libc", license = "MIT and component notices", text = "notices/musl-COPYRIGHT.txt" }),
    table.freeze({ name = "Linked dlmalloc allocator", license = "Public domain notice", text = "notices/dlmalloc-NOTICE.txt" }),
  }),
  licenses = table.freeze({
    ["notices/LuauSquared-MIT.txt"] = [[
MIT License

Copyright (c) 2026 Luau Squared contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

This license applies to hand-maintained Luau Squared code. It does not replace
dependency or generated-runtime licenses; see THIRD_PARTY_NOTICES.md.
]],
    ["notices/Texere-MIT.txt"] = [[
MIT License

Copyright (c) 2026 Texere contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]],
    ["notices/Luau-MIT.txt"] = [[
MIT License

Copyright (c) 2019-2026 Roblox Corporation
Copyright (c) 1994–2019 Lua.org, PUC-Rio.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]],
    ["notices/Lua-MIT.txt"] = [[
Copyright © 1994–2019 Lua.org, PUC-Rio.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. 
]],
    ["notices/Emscripten-MIT-NCSA.txt"] = [[
Emscripten is available under 2 licenses, the MIT license and the
University of Illinois/NCSA Open Source License.

Both are permissive open source licenses, with little if any
practical difference between them.

The reason for offering both is that (1) the MIT license is
well-known, while (2) the University of Illinois/NCSA Open Source
License allows Emscripten's code to be integrated upstream into
LLVM, which uses that license, should the opportunity arise.

The full text of both licenses follows.

==============================================================================

Copyright (c) 2010-2014 Emscripten authors, see AUTHORS file.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

==============================================================================

Copyright (c) 2010-2014 Emscripten authors, see AUTHORS file.
All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the
"Software"), to deal with the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

    Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimers.

    Redistributions in binary form must reproduce the above
    copyright notice, this list of conditions and the following disclaimers
    in the documentation and/or other materials provided with the
    distribution.

    Neither the names of Mozilla,
    nor the names of its contributors may be used to endorse
    or promote products derived from this Software without specific prior
    written permission. 

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR
ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS WITH THE SOFTWARE.

==============================================================================

This program uses portions of Node.js source code located in src/library_path.js,
in accordance with the terms of the MIT license. Node's license follows:

    """
        Copyright Joyent, Inc. and other Node contributors. All rights reserved.
        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to
        deal in the Software without restriction, including without limitation the
        rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
        sell copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in
        all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
        FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
        IN THE SOFTWARE.
    """

The musl libc project is bundled in this repo, and it has the MIT license, see
system/lib/libc/musl/COPYRIGHT

The third_party/ subdirectory contains code with other licenses. None of it is
used by default, but certain options use it (e.g., the optional closure compiler
flag will run closure compiler from third_party/).

]],
    ["notices/Emscripten-AUTHORS.txt"] = [[
Contributors to Emscripten may optionally add themselves to this list of
authors if they choose to do so. This is optional because the git history is
good enough for that purpose, and in fact most projects do not maintain such a
manual list.

While the file is not necessary, to preserve the history of the project we are
not removing it.

(Authors keep copyright of their contributions, of course; they just grant
a license to everyone to use it as detailed in LICENSE.)

* Alon Zakai <alonzakai@gmail.com> (copyright owned by Mozilla Foundation)
* Tim Dawborn <tim.dawborn@gmail.com>
* Max Shawabkeh <max99x@gmail.com>
* Sigmund Vik <sigmund_vik@yahoo.com>
* Jeff Terrace <jterrace@gmail.com>
* Benoit Tremblay <trembl.ben@gmail.com>
* Andreas Bergmeier <abergmeier@gmx.net>
* Ben Schwartz <bens@alum.mit.edu>
* David Claughton <dave@eclecticdave.com>
* David Yip <yipdw@member.fsf.org>
* Julien Hamaide <julien.hamaide@gmail.com>
* Ehsan Akhgari <ehsan.akhgari@gmail.com> (copyright owned by Mozilla Foundation)
* Adrian Taylor <adrian@macrobug.com>
* Richard Assar <richard.assar@gmail.com>
* Nathan Hammond <emscripten@nathanhammond.com>
* Behdad Esfahbod <behdad@behdad.org>
* David Benjamin <davidben@mit.edu>
* Pierre Renaux <pierre@talansoft.com>
* Brian Anderson <banderson@mozilla.com>
* Jon Bardin <diclophis@gmail.com>
* Jukka Jylänki <jujjyl@gmail.com>
* Aleksander Guryanov <caiiiycuk@gmail.com>
* Chad Austin <chad@chadaustin.me> (copyright owned by IMVU)
* nandhp <nandhp@gmail.com>
* YeZhongWen <linghuye2.0@gmail.com>
* Xingxing Pan <forandom@gmail.com>
* Justin Kerk <dopefishjustin@gmail.com>
* Andrea Bedini <andrea.bedini@gmail.com>
* James Pike <totoro.friend@chilon.net>
* Mokhtar Naamani <mokhtar.naamani@gmail.com>
* Benjamin Stover <benjamin.stover@gmail.com>
* Riccardo Magliocchetti <riccardo.magliocchetti@gmail.com>
* Janus Troelsen <janus.troelsen@stud.tu-darmstadt.de>
* Lars Schneider <lars.schneider@autodesk.com> (copyright owned by Autodesk, Inc.)
* Joel Martin <github@martintribe.org>
* Manuel Wellmann <manuel.wellmann@autodesk.com> (copyright owned by Autodesk, Inc.)
* Xuejie Xiao <xxuejie@gmail.com>
* Dominic Wong <dom@slowbunyip.org>
* Alan Kligman <alan.kligman@gmail.com> (copyright owned by Mozilla Foundation)
* Anthony Liot <wolfviking0@yahoo.com>
* Michael Riss <Michael.Riss@gmx.de>
* Jasper St. Pierre <jstpierre@mecheye.net>
* Manuel Schölling <manuel.schoelling@gmx.de>
* Bruce Mitchener, Jr. <bruce.mitchener@gmail.com>
* Michael Bishop <mbtyke@gmail.com>
* Roger Braun <roger@rogerbraun.net>
* Vladimir Vukicevic <vladimir@pobox.com> (copyright owned by Mozilla Foundation)
* Lorant Pinter <lorant.pinter@prezi.com>
* Tobias Doerffel <tobias.doerffel@gmail.com>
* Martin von Gagern <martin@von-gagern.net>
* Ting-Yuan Huang <thuang@mozilla.com>
* Joshua Granick <jgranick@blackberry.com>
* Felix H. Dahlke <fhd@ubercode.de>
* Éloi Rivard <azmeuk@gmail.com>
* Alexander Gladysh <ag@logiceditor.com>
* Arlo Breault <arlolra@gmail.com>
* Jacob Lee <artdent@gmail.com> (copyright owned by Google, Inc.)
* Joe Lee <jlee@imvu.com> (copyright owned by IMVU)
* Andy Friesen <andy@imvu.com> (copyright owned by IMVU)
* Bill Welden <bwelden@imvu.com> (copyright owned by IMVU)
* Michael Ey <mey@imvu.com> (copyright owned by IMVU)
* Llorens Marti Garcia <lgarcia@imvu.com> (copyright owned by IMVU)
* Jinsuck Kim <jkim@imvu.com> (copyright owned by IMVU)
* Todd Lee <tlee@imvu.com> (copyright owned by IMVU)
* Anthony Pesch <inolen@gmail.com>
* Robert Bragg <robert.bragg@intel.com> (copyright owned by Intel Corporation)
* Sylvestre Ledru <sylvestre@debian.org>
* Tom Fairfield <fairfield@cs.xu.edu>
* Anthony J. Thibault <ajt@hyperlogic.org>
* John Allwine <jallwine86@gmail.com>
* Martin Gerhardy <martin.gerhardy@gmail.com>
* James Gregory <jgregory@zynga.com> (copyright owned by Zynga, Inc.)
* Dan Gohman <sunfish@google.com> (copyright owned by Google, Inc.)
* Jeff Gilbert <jgilbert@mozilla.com> (copyright owned by Mozilla Foundation)
* Frits Talbot <frits@metapathy.com>
* Onno Jongbloed <hey@onnoj.net>
* Jez Ng <me@jezng.com>
* Marc Feeley <mfeeley@mozilla.com> (copyright owned by Mozilla Foundation)
* Ludovic Perrine <jazzzz@gmail.com>
* David Barksdale <david.barksdale@adcedosolutions.com>
* Manfred Manik Nerurkar <nerurkar*at*made-apps.biz> (copyright owned by MADE, GmbH)
* Joseph Gentle <me@josephg.com>
* Douglas T. Crosher <dtc-moz@scieneer.com> (copyright owned by Mozilla Foundation)
* Douglas T. Crosher <info@jsstats.com> (copyright owned by Scieneer Pty Ltd.)
* Soeren Balko <soeren.balko@gmail.com> (copyright owned by Clipchamp Pty Ltd.)
* Ryan Kelly (ryan@rfk.id.au)
* Michael Lelli <toadking@toadking.com>
* Yu Kobayashi <yukoba@accelart.jp>
* Pin Zhang <zhangpin04@gmail.com>
* Nick Bray <ncbray@chromium.org> (copyright owned by Google, Inc.)
* Aidan Hobson Sayers <aidanhs@cantab.net>
* Charlie Birks <admin@daftgames.net>
* Ranger Harke <ranger.harke@autodesk.com> (copyright owned by Autodesk, Inc.)
* Tobias Vrinssen <tobias@vrinssen.de>
* Patrick R. Martin <patrick.martin.r@gmail.com>
* Richard Quirk <richard.quirk@gmail.com>
* Marcos Scriven <marcos@scriven.org>
* Antoine Lambert <antoine.lambert33@gmail.com>
* Daniel Aquino <mr.danielaquino@gmail.com>
* Remi Papillie <remi.papillie@gmail.com>
* Fraser Adams <fraser.adams@blueyonder.co.uk>
* Michael Tirado <icetooth333@gmail.com>
* Ben Noordhuis <info@bnoordhuis.nl>
* Bob Roberts <bobroberts177@gmail.com>
* John Vilk <jvilk@cs.umass.edu>
* Daniel Baulig <dbaulig@fb.com> (copyright owned by Facebook, Inc.)
* Lu Wang <coolwanglu@gmail.com>
* Heidi Pan <heidi.pan@intel.com> (copyright owned by Intel)
* Vasilis Kalintiris <ehostunreach@gmail.com>
* Adam C. Clifton <adam@hulkamaniac.com>
* Volo Zyko <volo.zyko@gmail.com>
* Andre Weissflog <floooh@gmail.com>
* Alexandre Perrot <alexandre.perrot@gmail.com>
* Emerson José Silveira da Costa <emerson.costa@gmail.com>
* Jari Vetoniemi <mailroxas@gmail.com>
* Sindre Sorhus <sindresorhus@gmail.com>
* James S Urquhart <jamesu@gmail.com>
* Boris Gjenero <boris.gjenero@gmail.com>
* jonas echterhoff <jonas@unity3d.com>
* Sami Vaarala <sami.vaarala@iki.fi>
* Jack A. Arrington <jack@epicpineapple.com>
* Richard Janicek <r@janicek.co>
* Joel Croteau <jcroteau@gmail.com>
* Haneef Mubarak <haneef503@gmail.com>
* Nicolas Peri <nicox@shivaengine.com> (copyright owned by ShiVa Technologies, SAS)
* Bernhard Fey <e-male@web.de>
* Dave Nicponski <dave.nicponski@gmail.com>
* Jonathan Jarri <noxalus@gmail.com>
* Daniele Di Proietto <daniele.di.proietto@gmail.com>
* Dan Dascalescu <dNOSPAMdascalescu@gmail.com>
* Thomas Borsos <thomasborsos@gmail.com>
* Ori Avtalion <ori@avtalion.name>
* Guillaume Blanc <guillaumeblanc.sc@gmail.com>
* Usagi Ito <usagi@WonderRabbitProject.net>
* Camilo Polymeris <cpolymeris@gmail.com>
* Markus Henschel <markus.henschel@yager.de>
* Ophir Lojkine <ophir.lojkine@eleves.ec-nantes.fr>
* Ryan Sturgell <ryan.sturgell@gmail.com> (copyright owned by Google, Inc.)
* Jason Green <jason@transgaming.com> (copyright owned by TransGaming, Inc.)
* Ningxin Hu <ningxin.hu@intel.com> (copyright owned by Intel)
* Nicolas Guillemot <nlguillemot@gmail.com>
* Sathyanarayanan Gunasekaran <gsathya.ceg@gmail.com> (copyright owned by Mozilla Foundation)
* Nikolay Vorobyov <nik.vorobyov@gmail.com>
* Jonas Platte <mail@jonasplatte.de>
* Sebastien Ronsse <sronsse@gmail.com>
* Glenn R. Wichman <gwichman@zynga.com>
* Hamish Willee <hamishwillee@gmail.com> (copyright owned by Mozilla Foundation)
* Sylvain Chevalier <sylvain.chevalier@gmail.com>
* Nathan Ross <nross.se@gmail.com>
* Zachary Pomerantz <zmp@umich.edu>
* Boris Tsarev <boristsarev@gmail.com>
* Mark Logan <mark@artillery.com> (copyright owned by Artillery Games, Inc.)
* Коренберг Марк <socketpair@gmail.com>
* Gauthier Billot <gogoprog@gmail.com>
* Árpád Goretity <h2co3@h2co3.org>
* Nicholas Wilson <nicholas@nicholaswilson.me.uk>
* Aaron Mandle <aaronmandle@gmail.com>
* Bailey Hayes <Bailey.Hayes@sas.com> (copyright owned by SAS Institute Inc.)
* Paul Holland <pholland@adobe.com>
* James Long <longster@gmail.com>
* David Anderson <danderson@mozilla.com> (copyright owned by Mozilla Foundation)
* Eric Rannaud <e@nanocritical.com> (copyright owned by Nanocritical Corp.)
* William Furr <wfurr@google.com> (copyright owned by Google, Inc.)
* Dan Glastonbury <dglastonbury@mozilla.com> (copyright owned by Mozilla Foundation)
* Warren Seine <warren.seine@aerys.in> (copyright owned by Aerys SAS)
* Petr Babicka <babcca@gmail.com>
* Akira Takahashi <faithandbrave@gmail.com>
* Victor Costan <costan@gmail.com>
* Pepijn Van Eeckhoudt <pepijn.vaneeckhoudt@luciad.com> (copyright owned by Luciad NV)
* Stevie Trujillo <stevie.trujillo@gmail.com>
* Edward Rudd <urkle@outoforder.cc>
* Rene Eichhorn <rene.eichhorn1@gmail.com>
* Nick Desaulniers <nick@mozilla.com> (copyright owned by Mozilla Foundation)
* Luke Wagner <luke@mozilla.com> (copyright owned by Mozilla Foundation)
* Matt McCormick <matt.mccormick@kitware.com>
* Thaddée Tyl <thaddee.tyl@gmail.com>
* Philipp Wiesemann <philipp.wiesemann@arcor.de>
* Jan Jongboom <janjongboom@gmail.com> (copyright owned by Telenor Digital AS)
* Tiago Quelhas <tiagoq@gmail.com>
* Reinier de Blois <rddeblois@gmail.com>
* Yuichi Nishiwaki <yuichi.nishiwaki@gmail.com>
* Jérôme Bernard <jerome.bernard@ercom.fr> (copyright owned by Ercom)
* Chanhwi Choi <ccwpc@hanmail.net>
* Fábio Santos <fabiosantosart@gmail.com>
* Thibaut Despoulain <thibaut@artillery.com> (copyright owned by Artillery Games, Inc.)
* Wei Tjong Yao <weitjong@gmail.com>
* Tim Guan-tin Chien <timdream@gmail.com>
* Krzysztof Jakubowski <nadult@fastmail.fm>
* Vladimír Vondruš <mosra@centrum.cz>
* Brion Vibber <brion@pobox.com>
* Philip Lafleur <sendsbeak@gmail.com>
* Javier Meseguer de Paz <j.meseguer@gmail.com>
* Michael A. Balazs <michael.balazs@gmail.com>
* Andreas Blixt <me@blixt.nyc>
* Haofeng Zhang <h.z@duke.edu>
* Cody Welsh <codyw@protonmail.com>
* Hoong Ern Ng <hoongern@gmail.com>
* Kagami Hiiragi <kagami@genshiken.org>
* Jan Bölsche <jan@lagomorph.de>
* Sebastian Matthes <sebastianmatthes@outlook.com> (copyright owned by Volkswagen AG)
* Robert Goulet <robert.goulet@autodesk.com> (copyright owned by Autodesk, Inc.)
* Juha Järvi <befunge@gmail.com>
* Louis Lagrange <lagrange.louis@gmail.com>
* Ying-Ruei Liang <thumbd03803@gmail.com>
* Stuart Geipel <lapimlu@gmail.com>
* Yeonjun Lim <yjroot@gmail.com>
* Andrew Karpushin <reven86@gmail.com>
* Felix Zimmermann <fzimmermann89@gmail.com>
* Sven-Hendrik Haase <svenstaro@gmail.com>
* Simon Sandström <simon@nikanor.nu>
* Khaled Sami <k.sami.mohammed@gmail.com>
* Omar El-Mohandes <omar.elmohandes90@gmail.com>
* Florian Rival <florian.rival@gmail.com>
* Mark Achée <mark@achee.com>
* Piotr Paczkowski <kontakt@trzeci.eu>
* Braden MacDonald <braden@bradenmacdonald.com>
* Kevin Cheung <kevin.cheung@autodesk.com> (copyright owned by Autodesk, Inc.)
* Josh Peterson <petersonjm1@gmail.com>
* eska <eska@eska.me>
* Nate Burr <nate.oo@gmail.com>
* Paul "TBBle" Hampson <Paul.Hampson@Pobox.com>
* Andreas Plesch <andreasplesch@gmail.com>
* Brian Armstrong <brian.armstrong.ece+github@gmail.com>
* Vincenzo Chianese <vincenz.chianese@icloud.com>
* Noam T.Cohen <noam@ecb.co.il>
* Nick Shin <nick.shin@gmail.com>
* Gregg Tavares <github@greggman.com>
* Tanner Rogalsky <tanner@tannerrogalsky.com>
* Richard Cook <rcook@tableau.com> (copyright owned by Tableau Software, Inc.)
* Arnab Choudhury <achoudhury@tableau.com> (copyright owned by Tableau Software, Inc.)
* Charles Vaughn <cvaughn@tableau.com> (copyright owned by Tableau Software, Inc.)
* Pierre Krieger <pierre.krieger1708@gmail.com>
* Jakob Stoklund Olesen <stoklund@2pi.dk>
* Jérémy Anger <angerj.dev@gmail.com>
* Derek Schuff <dschuff@chromium.org> (copyright owned by Google, Inc.)
* Ashley Sommer <flubba86@gmail.com>
* Dave Fletcher <graveyhead@gmail.com>
* Lars-Magnus Skog <ralphtheninja@riseup.net>
* Pieter Vantorre <pietervantorre@gmail.com>
* Maher Sallam <maher@sallam.me>
* Andrey Burov <burik666@gmail.com>
* Holland Schutte <hgschutte1@gmail.com>
* Kerby Geffrard <kerby.geffrard@gmail.com>
* cynecx <me@cynecx.net>
* Chris Gibson <cgibson@mrvoxel.com>
* Harald Reingruber <code*at*h-reingruber.at>
* Aiden Koss <madd0131@umn.edu>
* Dustin VanLerberghe <good_ol_dv@hotmail.com>
* Philip Bielby <pmb45-github@srcf.ucam.org> (copyright owned by Jagex Ltd.)
* Régis Fénéon <regis.feneon@gmail.com>
* Dominic Chen <d.c.ddcc@gmail.com> (copyright owned by Google, Inc.)
* Junji Hashimoto <junji.hashimoto@gmail.com>
* Heejin Ahn <aheejin@gmail.com> (copyright owned by Google, Inc.)
* Andras Kucsma <andras.kucsma@gmail.com>
* Mateusz Borycki <mateuszborycki@gmail.com>
* Franklin Ta <fta2012@gmail.com>
* Jacob Gravelle <jgravelle@google.com> (copyright owned by Google, Inc.)
* Kagami Sascha Rosylight <saschanaz@outlook.com>
* Benny Jacobs <benny@gmx.it>
* Ray Brown <code@liquibits.com>
* Christopher Serr <christopher.serr@gmail.com>
* Aaron Ruß <aaron.russ@dfki.de> (copyright owned by DFKI GmbH)
* Vilibald Wanča <vilibald@wvi.cz>
* Alex Hixon <alex@alexhixon.com>
* Vladimir Davidovich <thy.ringo@gmail.com>
* Yuriy Levchenko <irov13@mail.ru>
* Dmitry Tolmachov <dmitolm@gmail.com>
* Dylan McKay <me@dylanmckay.io>
* Christophe Gragnic <cgragnic@netc.fr>
* Murphy McCauley <murphy.mccauley@gmail.com>
* Anatoly Trosinenko <anatoly.trosinenko@gmail.com>
* Brad Grantham <grantham@plunk.org>
* Sam Clegg <sbc@chromium.org> (copyright owned by Google, Inc.)
* Joshua Lind <joshualind007@hotmail.com>
* Hiroaki GOTO as "GORRY" <gorry@hauN.org>
* Mikhail Kremnyov <mkremnyov@gmail.com> (copyright owned by XCDS International)
* Tasuku SUENAGA a.k.a. gunyarakun <tasuku-s-github@titech.ac>
* Vitorio Miguel Prieto Cilia <vdrbandeiras@gmail.com>
* Evan Wallace <evan.exe@gmail.com>
* Henning Pohl <henning@still-hidden.de>
* Tim Neumann <mail@timnn.me>
* Ondrej Stava <ondrej.stava@gmail.com> (copyright owned by Google, Inc.)
* Jakub Jirutka <jakub@jirutka.cz>
* Loo Rong Jie <loorongjie@gmail.com>
* Jean-François Geyelin <jfgeyelin@gmail.com>
* Matthew Collins <thethinkofdeath@gmail.com>
* Satoshi N. M <snmatsutake@yahoo.co.jp>
* Ryan Speets <ryan@speets.ca>
* Fumiya Chiba <fumiya.chiba@nifty.com>
* Ryan C. Gordon <icculus@icculus.org>
* Inseok Lee <dlunch@gmail.com>
* Yair Levinson (copyright owned by Autodesk, Inc.)
* Matjaž Drolc <mdrolc@gmail.com>
* James Swift <james@3dengineer.com> (copyright owned by PSPDFKit GmbH)
* Ryan Lester <ryan@cyph.com> (copyright owned by Cyph, Inc.)
* Nikolay Zapolnov <zapolnov@gmail.com>
* Nazar Mokrynskyi <nazar@mokrynskyi.com>
* Yury Delendik <ydelendik@mozilla.com> (copyright owned by Mozilla Foundation)
* Kenneth Perry <thothonegan@gmail.com>
* Jim Mussared <jim.mussared@gmail.com>
* Dirk Vanden Boer <dirk.vdb@gmail.com>
* Mitchell Foley <mitchfoley@google.com> (copyright owned by Google, Inc.)
* Oleksandr Chekhovskyi <oleksandr.chekhovskyi@gmail.com>
* Michael Siebert <michael.siebert2k@gmail.com>
* Jonathan Hale <squareys@googlemail.com>
* Etienne Brateau <etienne.brateau@gmail.com>
* Zhiming Wang <zmwangx@gmail.com>
* Jameson Ernst <jameson@jpernst.com>
* Yoan Lecoq <yoanlecoq.io@gmail.com>
* Jiajie Hu <jiajie.hu@intel.com> (copyright owned by Intel Corporation)
* Kamil Klimek <naresh@tlen.pl>
* José Carlos Pujol <josecpujol(at)gmail.com>
* Dannii Willis <curiousdannii@gmail.com>
* Erik Dubbelboer <erik@dubbelboer.com>
* Sergey Tsatsulin <tsatsulin@gmail.com>
* varkor <github@varkor.com>
* Stuart Knightley <website@stuartk.com>
* Amadeus Guo <gliheng@foxmail.com>
* Nathan Froyd <froydnj@gmail.com> (copyright owned by Mozilla Foundation)
* Daniel Wirtz <dcode@dcode.io>
* Kibeom Kim <kk1674@nyu.edu>
* Marcel Klammer <m.klammer@tastenkunst.com>
* Axel Forsman <axelsfor@gmail.com>
* Ebrahim Byagowi <ebrahim@gnu.org>
* Thorsten Möller <thorsten.moeller@sbi.ch>
* Michael Droettboom <mdroettboom@mozilla.com>
* Nicolas Bouquet <hgy01@hieroglyphe.net>
* Miguel Saldivar <miguel.saldivar22@hotmail.com>
* Gert Van Hoey <gert.vanhoey@gmail.com>
* Valtteri Heikkilä <rnd@nic.fi>
* Daniel McNab <daniel.mcnab6+emcc(at)gmail.com>
* Tyler Limkemann <tslimkemann42 gmail.com>
* Ben Smith <binji@google.com> (copyright owned by Google, Inc.)
* Sylvain Beucler <beuc@beuc.net>
* Patrik Weiskircher <patrik@weiskircher.name>
* Tobias Widlund <widlundtobias(at)gmail.com>
* Rob Fors <mail@robfors.com>
* Mike Frysinger <vapier@chromium.org> (copyright owned by Google, Inc.)
* Sébasiten Crozet <developer@crozet.re>
* Andrey Nagikh <andrey@nagih.ru>
* Dzmitry Malyshau <dmalyshau@mozilla.com> (copyright owned by Mozilla Foundation)
* Bjorn Swenson <tie.372@gmail.com>
* Ryhor Spivak <grisha@rusteddreams.net>
* Jan Schär <jscissr@gmail.com>
* Ryhor Spivak <grisha@rusteddreams.net>
* Alexander Bich <quyse0@gmail.com>
* Ashleigh Thomas <ashleighbcthomas@gmail.com>
* Veniamin Petrenko <bjpbjpbjp10@gmail.com>
* Ian Henderson <ian@ianhenderson.org>
* Siim Kallas <siimkallas@gmail.com>
* Carl Woffenden <cwoffenden@gmail.com> (copyright owned by Numfum GmbH)
* Patrick Berger <patrick.berger@xmail.net> (copyright owned by Compusoft Group)
* Alexander Frank Lehmann <alexander.frank.lehmann@compusoftgroup.com> (copyright owned by Compusoft Group)
* Tommy Nguyen <tn0502@gmail.com>
* Thomas Schander <info@thomasschander.com> (copyright owned by Enscape GmbH)
* Benjamin S. Rodgers <acdimalev@gmail.com>
* Paul Shapiro <paul@mymonero.com>
* Elmo Todurov <elmo.todurov@eesti.ee>
* Zoltán Žarkov <zeko@freecivweb.org>
* Roman Yurchak <rth.yurchak@pm.me>
* Hampton Maxwell <me@hamptonmaxwell.com>
* Eric Fiselier <ericwf@google.com> (copyright owned by Google, Inc.)
* Sirapop Wongstapornpat <sirapop.wongstapornpat@student.oulu.fi>
* Matt Kane <m@mk.gg>
* Altan Özlü <altanozlu7@gmail.com>
* Mary S <ipadlover8322@gmail.com>
* Martin Birks <mbirks@gmail.com>
* Kirill Smelkov <kirr@nexedi.com> (copyright owned by Nexedi)
* Lutz Hören <laitch383@gmail.com>
* Pedro K Custodio <git@pedrokcustodio.com>
* Nicolas Allemand <contact@nicolasallemand.com>
* Gabriel Cuvillier <contact@gabrielcuvillier.pro>
* Thomas Lively <tlively@google.com> (copyright owned by Google, Inc.)
* Brandon Surmanski <b.surmanski@gmail.com>
* Rian Hunter <rian@alum.mit.edu>
* Kai Ninomiya <kainino@chromium.org> (copyright owned by Google, Inc.)
* Mickaël Schoentgen <contact@tiger-222.fr>
* Renaud Leroy <capitnflam@gmail.com>
* Florian Stellbrink <florian@stellbr.ink>
* Shane Peelar <lookatyouhacker@gmail.com>
* Alessandro Pignotti <alessandro@leaningtech.com>
* Zheng Tao Lee <zhengtao.lee@autodesk.com> (copyright owned by Autodesk, Inc.)
* Martina Kraus <kraus.martina.m@googlemail.com>
* Jacob Adelgren <jake@eevo.com>
* Ingvar Stepanyan <me@rreverser.com>
* Ben Trapani <ben.trapani1995@gmail.com> (copyright owned by Microsoft, Inc.)
* Tim Lander <tim57282＠hotmail.com>
* Jacob Greenfield <jacob@jacobgreenfield.me>
* Joseph Kogut <joseph.kogut@gmail.com>
* Yi Zhang <milizhang@gmail.com>
* Marc Abramowitz <msabramo@gmail.com>
* Daniel Ruf <daniel@daniel-ruf.de>
* Timothy Trindle <titrindl@microsoft.com> (copyright owned by Microsoft, Inc.)
* Matthew Andres Moreno <m.more500@gmail.com>
* Eric Mandel <eric@cfa.harvard.edu>
* Anthony Catel <paraboul@gmail.com>
* Simon Cooper <simon.d.cooper@hotmail.co.uk>
* Amir Rasouli <arasouli91@gmail.com>
* Nico Weber <thakis@chromium.org>
* Bas Doorn <code@keyn.app> (copyright owned by Keyn B.V.)
* Adam Bujalski <a.bujalski@samsung.com> (copyright owned by Samsung Electronics)
* Guanzhong Chen <gzchen@google.com> (copyright owned by Google, Inc.)
* Denis Serebro <densilver3000@gmail.com>
* Lucas Ramage <ramage.lucas@protonmail.com>
* Andy Wingo <wingo@igalia.com> (copyright owned by Igalia)
* Philipp Gloor <philipp.gloor@pdf-tools.com> (copyright owned by PDF Tools AG)
* Jasmine Minter <jasmine@minteronline.com> (copyright owned by Clipchamp Pty Ltd.)
* Ferris Kwaijtaal <ferrispc@hotmail.com>
* Konstantin Podsvirov <konstantin@podsvirov.pro>
* Eduardo Bart <edub4rt@gmail.com>
* Zoltan Varga <vargaz@gmail.com> (copyright owned by Microsoft, Inc.)
* Fernando Serboncini <fserb@google.com>
* Christian Clauss <cclauss@me.com> (copyright owned by IBM)
* Henry Kleynhans <hkleynhans@bloomberg.net> (copyright owned by Bloomberg L.P.)
* FUJI Goro <g.psy.va@gmail.com>
* Egor Suvorov <esuvorov@think-cell.com> (copyright owned by think-cell Software GmbH)
* James Kuszmaul <jabukuszmaul@gmail.com>
* Wei Mingzhi <whistler_wmz@users.sourceforge.net>
* Sergey karchevsky <sergey.ext@gmail.com>
* Ajay Patel <patel.ajay285@gmail.com>
* Adrien Devresse <adev@adev.name>
* Petr Penzin <petr.penzin@intel.com> (copyright owned by Intel Corporation)
* Tayeb Al Karim <tay@google.com> (copyright owned by Google, Inc.)
* Andrei Alexeyev <akari@taisei-project.org>
* Cesar Guirao Robles <cesar@no2.es>
* Ricky Claven <ricksterhd123@gmail.com>
* Mehdi Sabwat <mehdisabwat@gmail.com>
* MinganMuon <mingan-muon@outlook.com>
* Jonathan Feinberg <feinberg@google.com>
* Osman Turan <osman@osmanturan.com>
* Jaikanth J <jaikanthjay46@gmail.com>
* Gernot Lassnig <gernot.lassnig@gmail.com>
* Christian Boos <cboos@bct-technology.com>
* Erik Scholz <greenNO@SPAMg-s.xyz>
* Michael de Lang <kingoipo@gmail.com>
* Gergely Nagy <ngg@tresorit.com>
* Jan Habermann <jan@habermann.io>
* John Granström <granstrom.john@gmail.com>
* Clemens Backes <clemensb@google.com> (copyright owned by Google, Inc.)
* Tibor Klajnscek <tiborkl@numfum.com>
* Benjamin Golinvaux <benjamin@golinvaux.com>
* Peter Salomonsen <pjsalomonsen@gmail.com>
* Niklas Fiekas <niklas.fiekas@backscattering.de>
* Martín Lucas Golini <spartanj@gmail.com>
* Bumsik Kim <k.bumsik@gmail.com>
* Corentin Wallez <cwallez@chromium.org> (copyright owned by Google, Inc.)
* Austin Eng <enga@chromium.org> (copyright owned by Google, Inc.)
* Hugo Amiard <hugo.amiard@laposte.net>
* Diego Casorran <dcasorran@gmail.com>
* sssooonnnggg <sssooonnnggg111@gmail.com>
* Guillaume Racicot <gufideg@gmail.com>
* SK Min <oranke@gmail.com>
* Fabio Alessandrelli <fabio.alessandrelli@gmail.com>
* Kirill Gavrilov <kirill@sview.ru>
* Karl Semich <0xloem@gmail.com>
* Louis DeScioli <descioli@google.com> (copyright owned by Google, LLC)
* Kleis Auke Wolthuizen <info@kleisauke.nl>
* Michael Potthoff <michael@potthoff.eu>
* Abigail Bunyan <abigail@bold.claims> (copyright owned by Microsoft Corporation)
* David García Paredes <davidgparedes@gmail.com>
* Dan Field <dfield@gmail.com> (copyright owned by Google, Inc.)
* Mike Swierczek <mike@swierczek.io>
* Vasily <just.one.man@yandex.ru>
* Jānis Rūcis <parasti@gmail.com>
* rssqian <rssqian@gmail.com>
* Shachar Langbeheim <nihohit@gmail.com>
* Laurin Agostini <thevolut@gmail.com>
* David Carlier <devnexen@gmail.com>
* Paul Du <du.paul136@gmail.com> (copyright owned by ARSKAN)
* Piotr Doan <doanpiotr@gmail.com>
* Stuart Schechter <stuart.schechter@gmail.com>
* Brett Paterson <brett@fmod.com>
* Robert Aboukhalil <robert.aboukhalil@gmail.com>
* Jonathan Poelen <jonathan.poelen@gmail.com>
* Ashley Hauck <github@khyperia.com>
* Junyue Cao <junyuecao@gmail.com>
* Elías Serrano <feserr3@gmail.com>
* Philip Pfaffe <pfaffe@google.com> (copyright owned by Google, LLC)
* Troy Tae <tjy970721@gmail.com>
* Sky Wang <sky-wang@qq.com>
* popomen <nz_nuaa@163.com>
* Artyom Lebedev <vagran.ast@gmail.com>
* Sebastián Gurin (cancerberoSgx) <sebastigurin@gmail.com>
* Benedikt Meurer <bmeurer@google.com> (copyright owned by Google, LLC)
* Jiulong Wang <jiulongw@gmail.com>
* pudinha <rogi@skylittlesystem.org>
* Nicholas Phillips <nwp2@illinois.edu>
* Colin Guyon <colin.guyon@insimo.fr> (copyright owned by InSimo, SAS)
* Mathias Westerdahl <mwesterdahl76@gmail.com>
* Philip Rideout <prideout@google.com> (copyright owned by Google, LLC)
* Shrek Shao (shrekshao@google.com) (copyright owned by Google, LLC)
* Arran Ireland <ion92@protonmail.com>
* Jia Yuan Lo <jylo06g@gmail.com>
* Philip Lassen <philiplassen@gmail.com>
* Antoine du Hamel <duhamelantoine1995@gmail.com>
* Alexander Köplinger <alex.koeplinger@outlook.com> (copyright owned by Microsoft, Inc.)
* Kenneth Pouncey <kepounce@microsoft.com> (copyright owned by Microsoft, Inc.)
* Mitchell Hwang <mihw@microsoft.com> (copyright owned by Microsoft, Inc.)
* Sean Maher <seanptmaher@gmail.com> (copyright owned by Google, LLC)
* Paul Peny <pmpp.pub@gmail.com>
* Prashanth Nethi <prashant@adobe.com>
* Max Weisel <max@maxweisel.com>
* Georg Rottensteiner <georg@georg-rottensteiner.de>
* Tristan Griffin <tristan.griffin@hcl.com> (Copyright owned by HCL)
* Julien Jorge <julien.jorge@gmx.fr>
* Benjamin Lee <bnllee@ucdavis.edu>
* Attila Oláh <atl@google.com> (copyright owned by Google, LLC)
* Marat Dukhan <maratek@google.com> (copyright owned by Google, LLC)
* Raphael Siegel <siegel.raphael@gmail.com>
* Stephan Reiter <reste@google.com> (copyright owned by Google, LLC)
* kamenokonyokonyoko <kamenokonokotan@gmail.com>
* Lectem <lectem@gmail.com>
* Henrik Algestam <henrik@algestam.se>
* Rocco Musolino <roccomusolino92@gmail.com>
* Pawel Czarnecki <pawel@8thwall.com> (copyright owned by 8th Wall, Inc.)
* Dhairya Bahl < dhairyabahl5@gmail.com >
* Sam Gao <gaoshan274@gmail.com>
* Sebastian Mayr <me@sam.st>
* Vladimir Gamalyan <vladimir.gamalyan@gmail.com>
* Jean-Sébastien Nadeau <mundusnine@gmail.com> (copyright owned by Foundry Interactive Inc.)
* Wouter van Oortmerssen <wvo@google.com> (copyright owned by Google, LLC)
* Alexey Sokolov <sokolov@google.com> (copyright owned by Google, LLC)
* Lukas Rieger <rieger@progress-psd.com>
* Ivan Romanovski <ivan.romanovski@gmail.com>
* Max Brunsfeld <maxbrunsfeld@gmail.com>
* Basil Fierz <basil.fierz@hotmail.com>
* Rod Hyde <rod@badlydrawngames.com>
* Aleksey Kliger <aleksey@lambdageek.org> (copyright owned by Microsoft, Inc.)
* Nicolas Ollinger <nopid@free.fr>
* Michael R. Crusoe <crusoe@debian.org>
* Dexter Chua <dec41@srcf.net>
* Thomas Ballinger <thomasballinger@gmail.com>
* Mehdi Sadeghi <mehdi@mehdix.org>
* Amin Yahyaabadi <aminyahyaabadi74@gmail.com>
* Adam Leskis <leskis@gmail.com>
* Raffaele Pertile <raffarti@zoho.com>
* Patric Stout <github@truebrain.nl>
* Jinoh Kang <jinoh.kang.kr@gmail.com>
* Jorge Prendes <jorge.prendes@gmail.com>
* Alexey Shamrin <shamrin@gmail.com>
* Wirtos <wirtos.new@gmail.com>
* Ben den Hollander <bdenhollander@dynascape.com> (copyright owned by DynaScape Software Inc.)
* Akul Penugonda <akulvp@gmail.com>
* Jan Wolff <contact@jancc.de>
* Pawel Czarnecki <pawel@8thwall.com> (copyright owned by 8th Wall, Inc.)
* Camil Staps <info@camilstaps.nl>
* Michael Kircher <michael.kircher.github@gmail.com>
* Sharad Saxena <sharad.saxena@autodesk.com> (copyright owned by Autodesk, Inc.)
* Vasili Skurydzin <vasili.skurydzin@ibm.com>
* Jakub Nowakowski <jn925+emcc@o2.pl>
* Michael Taylor <mitaylor@adobe.com>
* Andrew Brown <andrew.brown@intel.com> (copyright owned by Intel Corporation)
* Benjamin Puzycki <bpuzycki@umich.edu>
* Marco Buono <marcobuono@invisionapp.com> (copyright owned by InVisionApp, Inc.)
* Philip Gossweiler <philip.gossweiler@outlook.com>
* Rafael Brune <mail@rbrune.de>
* Aleksi Sapon <aleksi.sapon@faro.com> (copyright owned by FARO Technologies, Inc.)
* Radek Doulik <radek.doulik@gmail.com> (copyright owned by Microsoft, Inc.)
* Érico Porto <ericoporto2008@gmail.com>
* Albert Vaca Cintora <albertvaka@gmail.com>
* Zhi An Ng <zhin@google.com> (copyright owned by Google, Inc.)
* Ian Jackson <ijackson@chiark.greenend.org.uk>
* Brian Gontowski <brian@gontowski.com>
* Bobbie Chen <bobbie.chen75@gmail.com>
* Nicholas Hollander <nhollander98@gmail.com>
* Camillo Lugaresi <camillol@google.com> (copyright owned by Google LLC)
* Chris Craig <emscripten@goldwave.com>
* Le Yao <le.yao@intel.com> (copyright owned by Intel Corporation)
* José Cadete <crudelios@gmail.com>
* Cynthia K. Rey <cynthia@cynthia.dev>
* Andrew Shaitorov <andrew.shaitorov@gmail.com>
* on-keyday <rokenboo47803@gmail.com>
* Matthew Balch <matt5sean3@gmail.com>
* James Price <jrprice@google.com> (copyright owned by Google, Inc.)
* Nathan Rugg <nmrugg@gmail.com> (copyright owned by Chess.com, LLC)
* Alexander O'Mara <me@alexomara.com>
* Kamaron Peterson <kamaron.peterson@gmail.com>
* Márton Marczell <mmarczell.graphisoft@gmail.com> (copyright owned by GRAPHISOFT SE)
* Alexander Vestin <alex.vestin@gmail.com>
* Xiaobing Yang <yangxiaobing@jwzg.com>
* Alexandra Cherdantseva <neluhus.vagus@gmail.com>
* Michael Schmuki <michael@schmuki.io>
* Skye Gibney <skyejgibney@gmail.com>
* Piotr Wierciński <laminowany@gmail.com>
* 郑苏波 (Super Zheng) <superzheng@tencent.com>
* James Hu <jameshu2022@gmail.com>
* Jerry Zhuang <jerry.zhuang@jwzg.com>
* Taisei Kon <kinsei0916@gmail.com>
* YAMAMOTO Takashi <yamamoto@midokura.com>
* Artur Gatin <agatin@teladochealth.com> (copyright owned by Teladoc Health, Inc.)
* Christian Lloyd <clloyd@teladochealth.com> (copyright owned by Teladoc Health, Inc.)
* Sean Morris <sean@seanmorr.is>
]],
    ["notices/LLVM-libcxx.txt"] = [[
==============================================================================
The LLVM Project is under the Apache License v2.0 with LLVM Exceptions:
==============================================================================

                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

    TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

    1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

    2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

    3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

    4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

    5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

    6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

    7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

    8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

    9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

    END OF TERMS AND CONDITIONS

    APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

    Copyright [yyyy] [name of copyright owner]

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.


---- LLVM Exceptions to the Apache 2.0 License ----

As an exception, if, as a result of your compiling your source code, portions
of this Software are embedded into an Object form of such source code, you
may redistribute such embedded portions in such Object form without complying
with the conditions of Sections 4(a), 4(b) and 4(d) of the License.

In addition, if you combine or link compiled forms of this Software with
software that is licensed under the GPLv2 ("Combined Software") and if a
court of competent jurisdiction determines that the patent provision (Section
3), the indemnity provision (Section 9) or other Section of the License
conflicts with the conditions of the GPLv2, you may retroactively and
prospectively choose to deem waived or otherwise exclude such Section(s) of
the License, but only in their entirety and only with respect to the Combined
Software.

==============================================================================
Software from third parties included in the LLVM Project:
==============================================================================
The LLVM Project contains third party software which is under different license
terms. All such code will be identified clearly using at least one of two
mechanisms:
1) It will be in a separate directory tree with its own `LICENSE.txt` or
   `LICENSE` file at the top containing the specific license and restrictions
   which apply to that software, or
2) It will contain specific license and restriction terms at the top of every
   file.

==============================================================================
Legacy LLVM License (https://llvm.org/docs/DeveloperPolicy.html#legacy):
==============================================================================

The libc++ library is dual licensed under both the University of Illinois
"BSD-Like" license and the MIT license.  As a user of this code you may choose
to use it under either license.  As a contributor, you agree to allow your code
to be used under both.

Full text of the relevant licenses is included below.

==============================================================================

University of Illinois/NCSA
Open Source License

Copyright (c) 2009-2019 by the contributors listed in CREDITS.TXT

All rights reserved.

Developed by:

    LLVM Team

    University of Illinois at Urbana-Champaign

    http://llvm.org

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal with
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimers.

    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimers in the
      documentation and/or other materials provided with the distribution.

    * Neither the names of the LLVM Team, University of Illinois at
      Urbana-Champaign, nor the names of its contributors may be used to
      endorse or promote products derived from this Software without specific
      prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS WITH THE
SOFTWARE.

==============================================================================

Copyright (c) 2009-2014 by the contributors listed in CREDITS.TXT

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]],
    ["notices/LLVM-libcxxabi.txt"] = [[
==============================================================================
The LLVM Project is under the Apache License v2.0 with LLVM Exceptions:
==============================================================================

                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

    TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

    1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

    2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

    3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

    4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

    5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

    6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

    7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

    8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

    9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

    END OF TERMS AND CONDITIONS

    APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

    Copyright [yyyy] [name of copyright owner]

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.


---- LLVM Exceptions to the Apache 2.0 License ----

As an exception, if, as a result of your compiling your source code, portions
of this Software are embedded into an Object form of such source code, you
may redistribute such embedded portions in such Object form without complying
with the conditions of Sections 4(a), 4(b) and 4(d) of the License.

In addition, if you combine or link compiled forms of this Software with
software that is licensed under the GPLv2 ("Combined Software") and if a
court of competent jurisdiction determines that the patent provision (Section
3), the indemnity provision (Section 9) or other Section of the License
conflicts with the conditions of the GPLv2, you may retroactively and
prospectively choose to deem waived or otherwise exclude such Section(s) of
the License, but only in their entirety and only with respect to the Combined
Software.

==============================================================================
Software from third parties included in the LLVM Project:
==============================================================================
The LLVM Project contains third party software which is under different license
terms. All such code will be identified clearly using at least one of two
mechanisms:
1) It will be in a separate directory tree with its own `LICENSE.txt` or
   `LICENSE` file at the top containing the specific license and restrictions
   which apply to that software, or
2) It will contain specific license and restriction terms at the top of every
   file.

==============================================================================
Legacy LLVM License (https://llvm.org/docs/DeveloperPolicy.html#legacy):
==============================================================================

The libc++abi library is dual licensed under both the University of Illinois
"BSD-Like" license and the MIT license.  As a user of this code you may choose
to use it under either license.  As a contributor, you agree to allow your code
to be used under both.

Full text of the relevant licenses is included below.

==============================================================================

University of Illinois/NCSA
Open Source License

Copyright (c) 2009-2019 by the contributors listed in CREDITS.TXT

All rights reserved.

Developed by:

    LLVM Team

    University of Illinois at Urbana-Champaign

    http://llvm.org

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal with
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimers.

    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimers in the
      documentation and/or other materials provided with the distribution.

    * Neither the names of the LLVM Team, University of Illinois at
      Urbana-Champaign, nor the names of its contributors may be used to
      endorse or promote products derived from this Software without specific
      prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS WITH THE
SOFTWARE.

==============================================================================

Copyright (c) 2009-2014 by the contributors listed in CREDITS.TXT

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]],
    ["notices/LLVM-compiler-rt.txt"] = [[
==============================================================================
The LLVM Project is under the Apache License v2.0 with LLVM Exceptions:
==============================================================================

                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

    TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

    1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

    2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

    3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

    4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

    5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

    6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

    7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

    8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

    9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

    END OF TERMS AND CONDITIONS

    APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

    Copyright [yyyy] [name of copyright owner]

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.


---- LLVM Exceptions to the Apache 2.0 License ----

As an exception, if, as a result of your compiling your source code, portions
of this Software are embedded into an Object form of such source code, you
may redistribute such embedded portions in such Object form without complying
with the conditions of Sections 4(a), 4(b) and 4(d) of the License.

In addition, if you combine or link compiled forms of this Software with
software that is licensed under the GPLv2 ("Combined Software") and if a
court of competent jurisdiction determines that the patent provision (Section
3), the indemnity provision (Section 9) or other Section of the License
conflicts with the conditions of the GPLv2, you may retroactively and
prospectively choose to deem waived or otherwise exclude such Section(s) of
the License, but only in their entirety and only with respect to the Combined
Software.

==============================================================================
Software from third parties included in the LLVM Project:
==============================================================================
The LLVM Project contains third party software which is under different license
terms. All such code will be identified clearly using at least one of two
mechanisms:
1) It will be in a separate directory tree with its own `LICENSE.txt` or
   `LICENSE` file at the top containing the specific license and restrictions
   which apply to that software, or
2) It will contain specific license and restriction terms at the top of every
   file.

==============================================================================
Legacy LLVM License (https://llvm.org/docs/DeveloperPolicy.html#legacy):
==============================================================================

The compiler_rt library is dual licensed under both the University of Illinois
"BSD-Like" license and the MIT license.  As a user of this code you may choose
to use it under either license.  As a contributor, you agree to allow your code
to be used under both.

Full text of the relevant licenses is included below.

==============================================================================

University of Illinois/NCSA
Open Source License

Copyright (c) 2009-2019 by the contributors listed in CREDITS.TXT

All rights reserved.

Developed by:

    LLVM Team

    University of Illinois at Urbana-Champaign

    http://llvm.org

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal with
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimers.

    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimers in the
      documentation and/or other materials provided with the distribution.

    * Neither the names of the LLVM Team, University of Illinois at
      Urbana-Champaign, nor the names of its contributors may be used to
      endorse or promote products derived from this Software without specific
      prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS WITH THE
SOFTWARE.

==============================================================================

Copyright (c) 2009-2015 by the contributors listed in CREDITS.TXT

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]],
    ["notices/musl-COPYRIGHT.txt"] = [[
musl as a whole is licensed under the following standard MIT license:

----------------------------------------------------------------------
Copyright Â© 2005-2020 Rich Felker, et al.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
----------------------------------------------------------------------

Authors/contributors include:

A. Wilcox
Ada Worcester
Alex Dowad
Alex Suykov
Alexander Monakov
Andre McCurdy
Andrew Kelley
Anthony G. Basile
Aric Belsito
Arvid Picciani
Bartosz Brachaczek
Benjamin Peterson
Bobby Bingham
Boris Brezillon
Brent Cook
Chris Spiegel
ClÃ©ment Vasseur
Daniel Micay
Daniel Sabogal
Daurnimator
David Carlier
David Edelsohn
Denys Vlasenko
Dmitry Ivanov
Dmitry V. Levin
Drew DeVault
Emil Renner Berthing
Fangrui Song
Felix Fietkau
Felix Janda
Gianluca Anzolin
Hauke Mehrtens
He X
Hiltjo Posthuma
Isaac Dunham
Jaydeep Patil
Jens Gustedt
Jeremy Huntwork
Jo-Philipp Wich
Joakim Sindholt
John Spencer
Julien Ramseier
Justin Cormack
Kaarle Ritvanen
Khem Raj
Kylie McClain
Leah Neukirchen
Luca Barbato
Luka Perkov
M Farkas-Dyck (Strake)
Mahesh Bodapati
Markus Wichmann
Masanori Ogino
Michael Clark
Michael Forney
Mikhail Kremnyov
Natanael Copa
Nicholas J. Kain
orc
Pascal Cuoq
Patrick Oppenlander
Petr Hosek
Petr Skocik
Pierre Carrier
Reini Urban
Rich Felker
Richard Pennington
Ryan Fairfax
Samuel Holland
Segev Finer
Shiz
sin
Solar Designer
Stefan Kristiansson
Stefan O'Rear
Szabolcs Nagy
Timo TerÃ¤s
Trutz Behn
Valentin Ochs
Will Dietz
William Haddon
William Pitcock

Portions of this software are derived from third-party works licensed
under terms compatible with the above MIT license:

The TRE regular expression implementation (src/regex/reg* and
src/regex/tre*) is Copyright Â© 2001-2008 Ville Laurikari and licensed
under a 2-clause BSD license (license text in the source files). The
included version has been heavily modified by Rich Felker in 2012, in
the interests of size, simplicity, and namespace cleanliness.

Much of the math library code (src/math/* and src/complex/*) is
Copyright Â© 1993,2004 Sun Microsystems or
Copyright Â© 2003-2011 David Schultz or
Copyright Â© 2003-2009 Steven G. Kargl or
Copyright Â© 2003-2009 Bruce D. Evans or
Copyright Â© 2008 Stephen L. Moshier or
Copyright Â© 2017-2018 Arm Limited
and labelled as such in comments in the individual source files. All
have been licensed under extremely permissive terms.

The ARM memcpy code (src/string/arm/memcpy.S) is Copyright Â© 2008
The Android Open Source Project and is licensed under a two-clause BSD
license. It was taken from Bionic libc, used on Android.

The AArch64 memcpy and memset code (src/string/aarch64/*) are
Copyright Â© 1999-2019, Arm Limited.

The implementation of DES for crypt (src/crypt/crypt_des.c) is
Copyright Â© 1994 David Burren. It is licensed under a BSD license.

The implementation of blowfish crypt (src/crypt/crypt_blowfish.c) was
originally written by Solar Designer and placed into the public
domain. The code also comes with a fallback permissive license for use
in jurisdictions that may not recognize the public domain.

The smoothsort implementation (src/stdlib/qsort.c) is Copyright Â© 2011
Valentin Ochs and is licensed under an MIT-style license.

The x86_64 port was written by Nicholas J. Kain and is licensed under
the standard MIT terms.

The mips and microblaze ports were originally written by Richard
Pennington for use in the ellcc project. The original code was adapted
by Rich Felker for build system and code conventions during upstream
integration. It is licensed under the standard MIT terms.

The mips64 port was contributed by Imagination Technologies and is
licensed under the standard MIT terms.

The powerpc port was also originally written by Richard Pennington,
and later supplemented and integrated by John Spencer. It is licensed
under the standard MIT terms.

All other files which have no copyright comments are original works
produced specifically for use as part of this library, written either
by Rich Felker, the main author of the library, or by one or more
contibutors listed above. Details on authorship of individual files
can be found in the git version control history of the project. The
omission of copyright and license comments in each file is in the
interest of source tree size.

In addition, permission is hereby granted for all public header files
(include/* and arch/*/bits/*) and crt files intended to be linked into
applications (crt/*, ldso/dlstart.c, and arch/*/crt_arch.h) to omit
the copyright notice and permission notice otherwise required by the
license, and to use these files without any requirement of
attribution. These files include substantial contributions from:

Bobby Bingham
John Spencer
Nicholas J. Kain
Rich Felker
Richard Pennington
Stefan Kristiansson
Szabolcs Nagy

all of whom have explicitly granted such permission.

This file previously contained text expressing a belief that most of
the files covered by the above exception were sufficiently trivial not
to be subject to copyright, resulting in confusion over whether it
negated the permissions granted in the license. In the spirit of
permissive licensing, and of not having licensing issues being an
obstacle to adoption, that text has been removed.
]],
    ["notices/dlmalloc-NOTICE.txt"] = [[
/*
 This is a version (aka dlmalloc) of malloc/free/realloc written by
 Doug Lea and released to the public domain, as explained at
 http://creativecommons.org/publicdomain/zero/1.0/ Send questions,
 comments, complaints, performance data, etc to dl@cs.oswego.edu
 
 * Version 2.8.6 Wed Aug 29 06:57:58 2012  Doug Lea
 Note: There may be an updated version of this malloc obtainable at
 ftp://gee.cs.oswego.edu/pub/misc/malloc.c
 Check before installing!
 
 * Quickstart
 
 This library is all in one file to simplify the most common usage:
 ftp it, compile it (-O3), and link it into another program. All of
 the compile-time options default to reasonable values for use on
 most platforms.  You might later want to step through various
 compile-time and dynamic tuning options.
 
 For convenience, an include file for code using this malloc is at:
 ftp://gee.cs.oswego.edu/pub/misc/malloc-2.8.6.h
 You don't really need this .h file unless you call functions not
 defined in your system include files.  The .h file contains only the
 excerpts from this file needed for using this malloc on ANSI C/C++
 systems, so long as you haven't changed compile-time options about
 naming and tuning parameters.  If you do, then you can create your
 own malloc.h that does include all settings by cutting at the point
 indicated below. Note that you may already by default be using a C
 library containing a malloc that is based on some version of this
 malloc (for example in linux). You might still want to use the one
 in this file to customize settings or to avoid overheads associated
 with library versions.
 
 * Vital statistics:
 
 Supported pointer/size_t representation:       4 or 8 bytes
 size_t MUST be an unsigned type of the same width as
 pointers. (If you are using an ancient system that declares
 size_t as a signed type, or need it to be a different width
 than pointers, you can use a previous release of this malloc
 (e.g. 2.7.2) supporting these.)
 
 Alignment:                                     8 bytes (minimum)
 This suffices for nearly all current machines and C compilers.
 However, you can define MALLOC_ALIGNMENT to be wider than this
 if necessary (up to 128bytes), at the expense of using more space.
 
 Minimum overhead per allocated chunk:   4 or  8 bytes (if 4byte sizes)
 8 or 16 bytes (if 8byte sizes)
 Each malloced chunk has a hidden word of overhead holding size
 and status information, and additional cross-check word
 if FOOTERS is defined.
 
 Minimum allocated size: 4-byte ptrs:  16 bytes    (including overhead)
 8-byte ptrs:  32 bytes    (including overhead)
 
 Even a request for zero bytes (i.e., malloc(0)) returns a
 pointer to something of the minimum allocatable size.
 The maximum overhead wastage (i.e., number of extra bytes
 allocated than were requested in malloc) is less than or equal
 to the minimum size, except for requests >= mmap_threshold that
 are serviced via mmap(), where the worst case wastage is about
 32 bytes plus the remainder from a system page (the minimal
 mmap unit); typically 4096 or 8192 bytes.
 
 Security: static-safe; optionally more or less
 The "security" of malloc refers to the ability of malicious
 code to accentuate the effects of errors (for example, freeing
 space that is not currently malloc'ed or overwriting past the
 ends of chunks) in code that calls malloc.  This malloc
 guarantees not to modify any memory locations below the base of
 heap, i.e., static variables, even in the presence of usage
 errors.  The routines additionally detect most improper frees
 and reallocs.  All this holds as long as the static bookkeeping
 for malloc itself is not corrupted by some other means.  This
 is only one aspect of security -- these checks do not, and
 cannot, detect all possible programming errors.
 
 If FOOTERS is defined nonzero, then each allocated chunk
 carries an additional check word to verify that it was malloced
 from its space.  These check words are the same within each
 execution of a program using malloc, but differ across
 executions, so externally crafted fake chunks cannot be
 freed. This improves security by rejecting frees/reallocs that
 could corrupt heap memory, in addition to the checks preventing
 writes to statics that are always on.  This may further improve
 security at the expense of time and space overhead.  (Note that
 FOOTERS may also be worth using with MSPACES.)
 
 By default detected errors cause the program to abort (calling
 "abort()"). You can override this to instead proceed past
 errors by defining PROCEED_ON_ERROR.  In this case, a bad free
 has no effect, and a malloc that encounters a bad address
 caused by user overwrites will ignore the bad address by
 dropping pointers and indices to all known memory. This may
 be appropriate for programs that should continue if at all
 possible in the face of programming errors, although they may
 run out of memory because dropped memory is never reclaimed.
 
 If you don't like either of these options, you can define
 CORRUPTION_ERROR_ACTION and USAGE_ERROR_ACTION to do anything
 else. And if if you are sure that your program using malloc has
 no errors or vulnerabilities, you can define INSECURE to 1,
 which might (or might not) provide a small performance improvement.
 
 It is also possible to limit the maximum total allocatable
 space, using malloc_set_footprint_limit. This is not
 designed as a security feature in itself (calls to set limits
 are not screened or privileged), but may be useful as one
 aspect of a secure implementation.
 
 Thread-safety: NOT thread-safe unless USE_LOCKS defined non-zero
 When USE_LOCKS is defined, each public call to malloc, free,
 etc is surrounded with a lock. By default, this uses a plain
 pthread mutex, win32 critical section, or a spin-lock if if
 available for the platform and not disabled by setting
 USE_SPIN_LOCKS=0.  However, if USE_RECURSIVE_LOCKS is defined,
 recursive versions are used instead (which are not required for
 base functionality but may be needed in layered extensions).
 Using a global lock is not especially fast, and can be a major
 bottleneck.  It is designed only to provide minimal protection
 in concurrent environments, and to provide a basis for
 extensions.  If you are using malloc in a concurrent program,
 consider instead using nedmalloc
 (http://www.nedprod.com/programs/portable/nedmalloc/) or
 ptmalloc (See http://www.malloc.de), which are derived from
 versions of this malloc.
 
 System requirements: Any combination of MORECORE and/or MMAP/MUNMAP
 This malloc can use unix sbrk or any emulation (invoked using
 the CALL_MORECORE macro) and/or mmap/munmap or any emulation
 (invoked using CALL_MMAP/CALL_MUNMAP) to get and release system
 memory.  On most unix systems, it tends to work best if both
 MORECORE and MMAP are enabled.  On Win32, it uses emulations
 based on VirtualAlloc. It also uses common C library functions
 like memset.
 
 Compliance: I believe it is compliant with the Single Unix Specification
 (See http://www.unix.org). Also SVID/XPG, ANSI C, and probably
 others as well.
 
 * Overview of algorithms
 
 This is not the fastest, most space-conserving, most portable, or
 most tunable malloc ever written. However it is among the fastest
 while also being among the most space-conserving, portable and
 tunable.  Consistent balance across these factors results in a good
 general-purpose allocator for malloc-intensive programs.
 
 In most ways, this malloc is a best-fit allocator. Generally, it
 chooses the best-fitting existing chunk for a request, with ties
 broken in approximately least-recently-used order. (This strategy
 normally maintains low fragmentation.) However, for requests less
 than 256bytes, it deviates from best-fit when there is not an
 exactly fitting available chunk by preferring to use space adjacent
 to that used for the previous small request, as well as by breaking
 ties in approximately most-recently-used order. (These enhance
 locality of series of small allocations.)  And for very large requests
 (>= 256Kb by default), it relies on system memory mapping
 facilities, if supported.  (This helps avoid carrying around and
 possibly fragmenting memory used only for large chunks.)
 
 All operations (except malloc_stats and mallinfo) have execution
 times that are bounded by a constant factor of the number of bits in
 a size_t, not counting any clearing in calloc or copying in realloc,
 or actions surrounding MORECORE and MMAP that have times
 proportional to the number of non-contiguous regions returned by
 system allocation routines, which is often just 1. In real-time
 applications, you can optionally suppress segment traversals using
 NO_SEGMENT_TRAVERSAL, which assures bounded execution even when
 system allocators return non-contiguous spaces, at the typical
 expense of carrying around more memory and increased fragmentation.
 
 The implementation is not very modular and seriously overuses
 macros. Perhaps someday all C compilers will do as good a job
 inlining modular code as can now be done by brute-force expansion,
 but now, enough of them seem not to.
 
 Some compilers issue a lot of warnings about code that is
 dead/unreachable only on some platforms, and also about intentional
 uses of negation on unsigned types. All known cases of each can be
 ignored.
 
 For a longer but out of date high-level description, see
 http://gee.cs.oswego.edu/dl/html/malloc.html
 
 * MSPACES
 If MSPACES is defined, then in addition to malloc, free, etc.,
 this file also defines mspace_malloc, mspace_free, etc. These
 are versions of malloc routines that take an "mspace" argument
 obtained using create_mspace, to control all internal bookkeeping.
 If ONLY_MSPACES is defined, only these versions are compiled.
 So if you would like to use this allocator for only some allocations,
 and your system malloc for others, you can compile with
 ONLY_MSPACES and then do something like...
 static mspace mymspace = create_mspace(0,0); // for example
 #define mymalloc(bytes)  mspace_malloc(mymspace, bytes)
 
 (Note: If you only need one instance of an mspace, you can instead
 use "USE_DL_PREFIX" to relabel the global malloc.)
 
 You can similarly create thread-local allocators by storing
 mspaces as thread-locals. For example:
 static __thread mspace tlms = 0;
 void*  tlmalloc(size_t bytes) {
 if (tlms == 0) tlms = create_mspace(0, 0);
 return mspace_malloc(tlms, bytes);
 }
 void  tlfree(void* mem) { mspace_free(tlms, mem); }
 
 Unless FOOTERS is defined, each mspace is completely independent.
 You cannot allocate from one and free to another (although
 conformance is only weakly checked, so usage errors are not always
 caught). If FOOTERS is defined, then each chunk carries around a tag
 indicating its originating mspace, and frees are directed to their
 originating spaces. Normally, this requires use of locks.
 
 -------------------------  Compile-time options ---------------------------
 
 Be careful in setting #define values for numerical constants of type
 size_t. On some systems, literal values are not automatically extended
 to size_t precision unless they are explicitly casted. You can also
 use the symbolic values MAX_SIZE_T, SIZE_T_ONE, etc below.
 
 WIN32                    default: defined if _WIN32 defined
 Defining WIN32 sets up defaults for MS environment and compilers.
 Otherwise defaults are for unix. Beware that there seem to be some
 cases where this malloc might not be a pure drop-in replacement for
 Win32 malloc: Random-looking failures from Win32 GDI API's (eg;
 SetDIBits()) may be due to bugs in some video driver implementations
 when pixel buffers are malloc()ed, and the region spans more than
 one VirtualAlloc()ed region. Because dlmalloc uses a small (64Kb)
 default granularity, pixel buffers may straddle virtual allocation
 regions more often than when using the Microsoft allocator.  You can
 avoid this by using VirtualAlloc() and VirtualFree() for all pixel
 buffers rather than using malloc().  If this is not possible,
 recompile this malloc with a larger DEFAULT_GRANULARITY. Note:
 in cases where MSC and gcc (cygwin) are known to differ on WIN32,
 conditions use _MSC_VER to distinguish them.
 
 DLMALLOC_EXPORT       default: extern
 Defines how public APIs are declared. If you want to export via a
 Windows DLL, you might define this as
 #define DLMALLOC_EXPORT extern  __declspec(dllexport)
 If you want a POSIX ELF shared object, you might use
 #define DLMALLOC_EXPORT extern __attribute__((visibility("default")))
 
 MALLOC_ALIGNMENT         default: (size_t)(2 * sizeof(void *))
 Controls the minimum alignment for malloc'ed chunks.  It must be a
 power of two and at least 8, even on machines for which smaller
 alignments would suffice. It may be defined as larger than this
 though. Note however that code and data structures are optimized for
 the case of 8-byte alignment.
 
 MSPACES                  default: 0 (false)
 If true, compile in support for independent allocation spaces.
 This is only supported if HAVE_MMAP is true.
 
 ONLY_MSPACES             default: 0 (false)
 If true, only compile in mspace versions, not regular versions.
 
 USE_LOCKS                default: 0 (false)
 Causes each call to each public routine to be surrounded with
 pthread or WIN32 mutex lock/unlock. (If set true, this can be
 overridden on a per-mspace basis for mspace versions.) If set to a
 non-zero value other than 1, locks are used, but their
 implementation is left out, so lock functions must be supplied manually,
 as described below.
 
 USE_SPIN_LOCKS           default: 1 iff USE_LOCKS and spin locks available
 If true, uses custom spin locks for locking. This is currently
 supported only gcc >= 4.1, older gccs on x86 platforms, and recent
 MS compilers.  Otherwise, posix locks or win32 critical sections are
 used.
 
 USE_RECURSIVE_LOCKS      default: not defined
 If defined nonzero, uses recursive (aka reentrant) locks, otherwise
 uses plain mutexes. This is not required for malloc proper, but may
 be needed for layered allocators such as nedmalloc.
 
 LOCK_AT_FORK            default: not defined
 If defined nonzero, performs pthread_atfork upon initialization
 to initialize child lock while holding parent lock. The implementation
 assumes that pthread locks (not custom locks) are being used. In other
 cases, you may need to customize the implementation.
 
 FOOTERS                  default: 0
 If true, provide extra checking and dispatching by placing
 information in the footers of allocated chunks. This adds
 space and time overhead.
 
 INSECURE                 default: 0
 If true, omit checks for usage errors and heap space overwrites.
 
 USE_DL_PREFIX            default: NOT defined
 Causes compiler to prefix all public routines with the string 'dl'.
 This can be useful when you only want to use this malloc in one part
 of a program, using your regular system malloc elsewhere.
 
 MALLOC_INSPECT_ALL       default: NOT defined
 If defined, compiles malloc_inspect_all and mspace_inspect_all, that
 perform traversal of all heap space.  Unless access to these
 functions is otherwise restricted, you probably do not want to
 include them in secure implementations.
 
 ABORT                    default: defined as abort()
 Defines how to abort on failed checks.  On most systems, a failed
 check cannot die with an "assert" or even print an informative
 message, because the underlying print routines in turn call malloc,
 which will fail again.  Generally, the best policy is to simply call
 abort(). It's not very useful to do more than this because many
 errors due to overwriting will show up as address faults (null, odd
 addresses etc) rather than malloc-triggered checks, so will also
 abort.  Also, most compilers know that abort() does not return, so
 can better optimize code conditionally calling it.
 
 PROCEED_ON_ERROR           default: defined as 0 (false)
 Controls whether detected bad addresses cause them to bypassed
 rather than aborting. If set, detected bad arguments to free and
 realloc are ignored. And all bookkeeping information is zeroed out
 upon a detected overwrite of freed heap space, thus losing the
 ability to ever return it from malloc again, but enabling the
 application to proceed. If PROCEED_ON_ERROR is defined, the
 static variable malloc_corruption_error_count is compiled in
 and can be examined to see if errors have occurred. This option
 generates slower code than the default abort policy.
 
 DEBUG                    default: NOT defined
 The DEBUG setting is mainly intended for people trying to modify
 this code or diagnose problems when porting to new platforms.
 However, it may also be able to better isolate user errors than just
 using runtime checks.  The assertions in the check routines spell
 out in more detail the assumptions and invariants underlying the
 algorithms.  The checking is fairly extensive, and will slow down
 execution noticeably. Calling malloc_stats or mallinfo with DEBUG
 set will attempt to check every non-mmapped allocated and free chunk
 in the course of computing the summaries.
 
 ABORT_ON_ASSERT_FAILURE   default: defined as 1 (true)
 Debugging assertion failures can be nearly impossible if your
 version of the assert macro causes malloc to be called, which will
 lead to a cascade of further failures, blowing the runtime stack.
 ABORT_ON_ASSERT_FAILURE cause assertions failures to call abort(),
 which will usually make debugging easier.
 
 MALLOC_FAILURE_ACTION     default: sets errno to ENOMEM, or no-op on win32
 The action to take before "return 0" when malloc fails to be able to
 return memory because there is none available.
 
 HAVE_MORECORE             default: 1 (true) unless win32 or ONLY_MSPACES
 True if this system supports sbrk or an emulation of it.
 
 MORECORE                  default: sbrk
 The name of the sbrk-style system routine to call to obtain more
 memory.  See below for guidance on writing custom MORECORE
 functions. The type of the argument to sbrk/MORECORE varies across
 systems.  It cannot be size_t, because it supports negative
 arguments, so it is normally the signed type of the same width as
 size_t (sometimes declared as "intptr_t").  It doesn't much matter
 though. Internally, we only call it with arguments less than half
 the max value of a size_t, which should work across all reasonable
 possibilities, although sometimes generating compiler warnings.
 
 MORECORE_CONTIGUOUS       default: 1 (true) if HAVE_MORECORE
 If true, take advantage of fact that consecutive calls to MORECORE
 with positive arguments always return contiguous increasing
 addresses.  This is true of unix sbrk. It does not hurt too much to
 set it true anyway, since malloc copes with non-contiguities.
 Setting it false when definitely non-contiguous saves time
 and possibly wasted space it would take to discover this though.
 
 UNSIGNED_MORECORE         default: 0 (false)
 True if MORECORE can only handle unsigned arguments. This sets
 MORECORE_CANNOT_TRIM to 1 (true).

 MORECORE_CANNOT_TRIM      default: NOT defined
 True if MORECORE cannot release space back to the system when given
 negative arguments. This is generally necessary only if you are
 using a hand-crafted MORECORE function that cannot handle negative
 arguments.
 
 NO_SEGMENT_TRAVERSAL       default: 0
 If non-zero, suppresses traversals of memory segments
 returned by either MORECORE or CALL_MMAP. This disables
 merging of segments that are contiguous, and selectively
 releasing them to the OS if unused, but bounds execution times.
 
 HAVE_MMAP                 default: 1 (true)
 True if this system supports mmap or an emulation of it.  If so, and
 HAVE_MORECORE is not true, MMAP is used for all system
 allocation. If set and HAVE_MORECORE is true as well, MMAP is
 primarily used to directly allocate very large blocks. It is also
 used as a backup strategy in cases where MORECORE fails to provide
 space from system. Note: A single call to MUNMAP is assumed to be
 able to unmap memory that may have be allocated using multiple calls
 to MMAP, so long as they are adjacent.
 
 HAVE_MREMAP               default: 1 on linux, else 0
 If true realloc() uses mremap() to re-allocate large blocks and
 extend or shrink allocation spaces.
 
 MMAP_CLEARS               default: 1 except on WINCE.
 True if mmap clears memory so calloc doesn't need to. This is true
 for standard unix mmap using /dev/zero and on WIN32 except for WINCE.
 
 USE_BUILTIN_FFS            default: 0 (i.e., not used)
 Causes malloc to use the builtin ffs() function to compute indices.
 Some compilers may recognize and intrinsify ffs to be faster than the
 supplied C version. Also, the case of x86 using gcc is special-cased
 to an asm instruction, so is already as fast as it can be, and so
 this setting has no effect. Similarly for Win32 under recent MS compilers.
 (On most x86s, the asm version is only slightly faster than the C version.)
 
 malloc_getpagesize         default: derive from system includes, or 4096.
 The system page size. To the extent possible, this malloc manages
 memory from the system in page-size units.  This may be (and
 usually is) a function rather than a constant. This is ignored
 if WIN32, where page size is determined using getSystemInfo during
 initialization.
 
 USE_DEV_RANDOM             default: 0 (i.e., not used)
 Causes malloc to use /dev/random to initialize secure magic seed for
 stamping footers. Otherwise, the current time is used.
 
 NO_MALLINFO                default: 0
 If defined, don't compile "mallinfo". This can be a simple way
 of dealing with mismatches between system declarations and
 those in this file.
 
 MALLINFO_FIELD_TYPE        default: size_t
 The type of the fields in the mallinfo struct. This was originally
 defined as "int" in SVID etc, but is more usefully defined as
 size_t. The value is used only if  HAVE_USR_INCLUDE_MALLOC_H is not set
 
 NO_MALLOC_STATS            default: 0
 If defined, don't compile "malloc_stats". This avoids calls to
 fprintf and bringing in stdio dependencies you might not want.
 
 REALLOC_ZERO_BYTES_FREES    default: not defined
 This should be set if a call to realloc with zero bytes should
 be the same as a call to free. Some people think it should. Otherwise,
 since this malloc returns a unique pointer for malloc(0), so does
 realloc(p, 0).
 
 LACKS_UNISTD_H, LACKS_FCNTL_H, LACKS_SYS_PARAM_H, LACKS_SYS_MMAN_H
 LACKS_STRINGS_H, LACKS_STRING_H, LACKS_SYS_TYPES_H,  LACKS_ERRNO_H
 LACKS_STDLIB_H LACKS_SCHED_H LACKS_TIME_H  default: NOT defined unless on WIN32
 Define these if your system does not have these header files.
 You might need to manually insert some of the declarations they provide.
 
 DEFAULT_GRANULARITY        default: page size if MORECORE_CONTIGUOUS,
 system_info.dwAllocationGranularity in WIN32,
 otherwise 64K.
 Also settable using mallopt(M_GRANULARITY, x)
 The unit for allocating and deallocating memory from the system.  On
 most systems with contiguous MORECORE, there is no reason to
 make this more than a page. However, systems with MMAP tend to
 either require or encourage larger granularities.  You can increase
 this value to prevent system allocation functions to be called so
 often, especially if they are slow.  The value must be at least one
 page and must be a power of two.  Setting to 0 causes initialization
 to either page size or win32 region size.  (Note: In previous
 versions of malloc, the equivalent of this option was called
 "TOP_PAD")
 
 DEFAULT_TRIM_THRESHOLD    default: 2MB
 Also settable using mallopt(M_TRIM_THRESHOLD, x)
 The maximum amount of unused top-most memory to keep before
 releasing via malloc_trim in free().  Automatic trimming is mainly
 useful in long-lived programs using contiguous MORECORE.  Because
 trimming via sbrk can be slow on some systems, and can sometimes be
 wasteful (in cases where programs immediately afterward allocate
 more large chunks) the value should be high enough so that your
 overall system performance would improve by releasing this much
 memory.  As a rough guide, you might set to a value close to the
 average size of a process (program) running on your system.
 Releasing this much memory would allow such a process to run in
 memory.  Generally, it is worth tuning trim thresholds when a
 program undergoes phases where several large chunks are allocated
 and released in ways that can reuse each other's storage, perhaps
 mixed with phases where there are no such chunks at all. The trim
 value must be greater than page size to have any useful effect.  To
 disable trimming completely, you can set to MAX_SIZE_T. Note that the trick
 some people use of mallocing a huge space and then freeing it at
 program startup, in an attempt to reserve system memory, doesn't
 have the intended effect under automatic trimming, since that memory
 will immediately be returned to the system.
 
 DEFAULT_MMAP_THRESHOLD       default: 256K
 Also settable using mallopt(M_MMAP_THRESHOLD, x)
 The request size threshold for using MMAP to directly service a
 request. Requests of at least this size that cannot be allocated
 using already-existing space will be serviced via mmap.  (If enough
 normal freed space already exists it is used instead.)  Using mmap
 segregates relatively large chunks of memory so that they can be
 individually obtained and released from the host system. A request
 serviced through mmap is never reused by any other request (at least
 not directly; the system may just so happen to remap successive
 requests to the same locations).  Segregating space in this way has
 the benefits that: Mmapped space can always be individually released
 back to the system, which helps keep the system level memory demands
 of a long-lived program low.  Also, mapped memory doesn't become
 `locked' between other chunks, as can happen with normally allocated
 chunks, which means that even trimming via malloc_trim would not
 release them.  However, it has the disadvantage that the space
 cannot be reclaimed, consolidated, and then used to service later
 requests, as happens with normal chunks.  The advantages of mmap
 nearly always outweigh disadvantages for "large" chunks, but the
 value of "large" may vary across systems.  The default is an
 empirically derived value that works well in most systems. You can
 disable mmap by setting to MAX_SIZE_T.
 
 MAX_RELEASE_CHECK_RATE   default: 4095 unless not HAVE_MMAP
 The number of consolidated frees between checks to release
 unused segments when freeing. When using non-contiguous segments,
 especially with multiple mspaces, checking only for topmost space
 doesn't always suffice to trigger trimming. To compensate for this,
 free() will, with a period of MAX_RELEASE_CHECK_RATE (or the
 current number of segments, if greater) try to release unused
 segments to the OS when freeing chunks that result in
 consolidation. The best value for this parameter is a compromise
 between slowing down frees with relatively costly checks that
 rarely trigger versus holding on to unused memory. To effectively
 disable, set to MAX_SIZE_T. This may lead to a very slight speed
 improvement at the expense of carrying around more memory.
 */
]],
  }),
})
