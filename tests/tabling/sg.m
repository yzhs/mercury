% This is the same generation program on a 24-24-2 cylinder.

:- module sg.

:- interface.

:- import_module io.

:- pred main(io__state::di, io__state::uo) is det.

:- implementation.

:- import_module std_util, int, list.

main -->
	{ solutions(sg1, Solns1) },
	io__write(Solns1),
	%% io__write_string("\n"),
	%% { solutions(sg, Solns) },
	%% io__write(Solns),
	io__write_string("\n").

% :- pred sg(pair(int,int)::out) is nondet.
% sg(X-Y) :- tsg(X,Y).

% just to test a non-open call.
:- pred sg1(int::out) is nondet.
sg1(X) :- tsg(1,X).

:- pred tsg(int, int).
:- mode tsg(in, out) is nondet.
% :- mode tsg(out, out) is nondet.
:- pragma minimal_model(tsg/2).

tsg(X,Y) :- cyl(X,X1), tsg(X1,Y1), acyl(Y1,Y).
tsg(X,X).

:- pred cyl(int, int).
:- mode cyl(in, out) is nondet.
% :- mode cyl(out, out) is multi.

cyl(1,30).
cyl(1,40).
cyl(2,43).
cyl(2,34).
cyl(3,30).
cyl(3,33).
cyl(4,45).
cyl(4,40).
cyl(5,31).
cyl(5,45).
cyl(6,31).
cyl(6,48).
cyl(7,31).
cyl(7,41).
cyl(8,25).
cyl(8,30).
cyl(9,40).
cyl(9,31).
cyl(10,35).
cyl(10,46).
cyl(11,32).
cyl(11,28).
cyl(12,35).
cyl(12,43).
cyl(13,46).
cyl(13,48).
cyl(14,39).
cyl(14,35).
cyl(15,46).
cyl(15,28).
cyl(16,28).
cyl(16,42).
cyl(17,33).
cyl(17,25).
cyl(18,46).
cyl(18,27).
cyl(19,38).
cyl(19,47).
cyl(20,27).
cyl(20,41).
cyl(21,34).
cyl(21,38).
cyl(22,27).
cyl(22,33).
cyl(23,26).
cyl(23,35).
cyl(24,36).
cyl(24,25).
cyl(25,70).
cyl(25,52).
cyl(26,59).
cyl(26,71).
cyl(27,61).
cyl(27,58).
cyl(28,61).
cyl(28,54).
cyl(29,63).
cyl(29,70).
cyl(30,58).
cyl(30,53).
cyl(31,56).
cyl(31,60).
cyl(32,58).
cyl(32,50).
cyl(33,62).
cyl(33,66).
cyl(34,55).
cyl(34,72).
cyl(35,63).
cyl(35,58).
cyl(36,55).
cyl(36,64).
cyl(37,56).
cyl(37,58).
cyl(38,68).
cyl(38,61).
cyl(39,64).
cyl(39,52).
cyl(40,57).
cyl(40,70).
cyl(41,69).
cyl(41,55).
cyl(42,62).
cyl(42,53).
cyl(43,68).
cyl(43,65).
cyl(44,56).
cyl(44,62).
cyl(45,67).
cyl(45,71).
cyl(46,71).
cyl(46,66).
cyl(47,61).
cyl(47,60).
cyl(48,60).
cyl(48,54).
cyl(49,93).
cyl(49,88).
cyl(50,90).
cyl(50,93).
cyl(51,95).
cyl(51,92).
cyl(52,93).
cyl(52,94).
cyl(53,83).
cyl(53,90).
cyl(54,78).
cyl(54,79).
cyl(55,79).
cyl(55,92).
cyl(56,96).
cyl(56,94).
cyl(57,94).
cyl(57,80).
cyl(58,79).
cyl(58,83).
cyl(59,75).
cyl(59,96).
cyl(60,86).
cyl(60,79).
cyl(61,85).
cyl(61,75).
cyl(62,82).
cyl(62,95).
cyl(63,85).
cyl(63,78).
cyl(64,92).
cyl(64,86).
cyl(65,76).
cyl(65,78).
cyl(66,78).
cyl(66,81).
cyl(67,96).
cyl(67,78).
cyl(68,88).
cyl(68,77).
cyl(69,86).
cyl(69,90).
cyl(70,93).
cyl(70,80).
cyl(71,92).
cyl(71,74).
cyl(72,88).
cyl(72,81).
cyl(73,113).
cyl(73,116).
cyl(74,101).
cyl(74,100).
cyl(75,113).
cyl(75,109).
cyl(76,112).
cyl(76,98).
cyl(77,109).
cyl(77,108).
cyl(78,112).
cyl(78,117).
cyl(79,101).
cyl(79,110).
cyl(80,110).
cyl(80,119).
cyl(81,108).
cyl(81,98).
cyl(82,111).
cyl(82,113).
cyl(83,116).
cyl(83,111).
cyl(84,114).
cyl(84,103).
cyl(85,97).
cyl(85,114).
cyl(86,107).
cyl(86,120).
cyl(87,116).
cyl(87,105).
cyl(88,99).
cyl(88,105).
cyl(89,118).
cyl(89,110).
cyl(90,104).
cyl(90,108).
cyl(91,98).
cyl(91,106).
cyl(92,100).
cyl(92,108).
cyl(93,117).
cyl(93,114).
cyl(94,115).
cyl(94,118).
cyl(95,99).
cyl(95,108).
cyl(96,111).
cyl(96,98).
cyl(97,125).
cyl(97,132).
cyl(98,134).
cyl(98,131).
cyl(99,124).
cyl(99,136).
cyl(100,122).
cyl(100,129).
cyl(101,140).
cyl(101,125).
cyl(102,142).
cyl(102,137).
cyl(103,137).
cyl(103,141).
cyl(104,135).
cyl(104,132).
cyl(105,126).
cyl(105,137).
cyl(106,142).
cyl(106,128).
cyl(107,123).
cyl(107,143).
cyl(108,126).
cyl(108,132).
cyl(109,128).
cyl(109,130).
cyl(110,124).
cyl(110,136).
cyl(111,123).
cyl(111,141).
cyl(112,128).
cyl(112,142).
cyl(113,130).
cyl(113,128).
cyl(114,144).
cyl(114,139).
cyl(115,141).
cyl(115,139).
cyl(116,134).
cyl(116,126).
cyl(117,135).
cyl(117,131).
cyl(118,137).
cyl(118,142).
cyl(119,133).
cyl(119,125).
cyl(120,135).
cyl(120,139).
cyl(121,154).
cyl(121,151).
cyl(122,150).
cyl(122,156).
cyl(123,158).
cyl(123,168).
cyl(124,160).
cyl(124,168).
cyl(125,159).
cyl(125,161).
cyl(126,167).
cyl(126,156).
cyl(127,151).
cyl(127,167).
cyl(128,164).
cyl(128,152).
cyl(129,154).
cyl(129,158).
cyl(130,164).
cyl(130,150).
cyl(131,165).
cyl(131,155).
cyl(132,154).
cyl(132,157).
cyl(133,163).
cyl(133,161).
cyl(134,147).
cyl(134,160).
cyl(135,156).
cyl(135,148).
cyl(136,153).
cyl(136,157).
cyl(137,159).
cyl(137,152).
cyl(138,149).
cyl(138,152).
cyl(139,161).
cyl(139,157).
cyl(140,167).
cyl(140,161).
cyl(141,168).
cyl(141,145).
cyl(142,161).
cyl(142,160).
cyl(143,146).
cyl(143,150).
cyl(144,160).
cyl(144,163).
cyl(145,184).
cyl(145,171).
cyl(146,187).
cyl(146,171).
cyl(147,179).
cyl(147,182).
cyl(148,185).
cyl(148,180).
cyl(149,187).
cyl(149,174).
cyl(150,175).
cyl(150,190).
cyl(151,176).
cyl(151,185).
cyl(152,169).
cyl(152,182).
cyl(153,181).
cyl(153,188).
cyl(154,190).
cyl(154,179).
cyl(155,184).
cyl(155,187).
cyl(156,169).
cyl(156,184).
cyl(157,183).
cyl(157,186).
cyl(158,174).
cyl(158,179).
cyl(159,175).
cyl(159,172).
cyl(160,190).
cyl(160,189).
cyl(161,180).
cyl(161,175).
cyl(162,192).
cyl(162,182).
cyl(163,179).
cyl(163,175).
cyl(164,174).
cyl(164,181).
cyl(165,178).
cyl(165,185).
cyl(166,170).
cyl(166,169).
cyl(167,183).
cyl(167,178).
cyl(168,180).
cyl(168,181).
cyl(169,213).
cyl(169,207).
cyl(170,206).
cyl(170,203).
cyl(171,195).
cyl(171,209).
cyl(172,214).
cyl(172,197).
cyl(173,205).
cyl(173,206).
cyl(174,212).
cyl(174,214).
cyl(175,201).
cyl(175,204).
cyl(176,206).
cyl(176,200).
cyl(177,202).
cyl(177,207).
cyl(178,202).
cyl(178,203).
cyl(179,216).
cyl(179,196).
cyl(180,211).
cyl(180,197).
cyl(181,193).
cyl(181,207).
cyl(182,196).
cyl(182,194).
cyl(183,215).
cyl(183,199).
cyl(184,203).
cyl(184,204).
cyl(185,196).
cyl(185,208).
cyl(186,195).
cyl(186,212).
cyl(187,193).
cyl(187,194).
cyl(188,204).
cyl(188,200).
cyl(189,205).
cyl(189,201).
cyl(190,210).
cyl(190,194).
cyl(191,193).
cyl(191,209).
cyl(192,208).
cyl(192,209).
cyl(193,227).
cyl(193,223).
cyl(194,240).
cyl(194,227).
cyl(195,239).
cyl(195,230).
cyl(196,228).
cyl(196,230).
cyl(197,234).
cyl(197,221).
cyl(198,240).
cyl(198,222).
cyl(199,221).
cyl(199,235).
cyl(200,230).
cyl(200,235).
cyl(201,230).
cyl(201,225).
cyl(202,238).
cyl(202,217).
cyl(203,224).
cyl(203,217).
cyl(204,221).
cyl(204,234).
cyl(205,228).
cyl(205,217).
cyl(206,221).
cyl(206,230).
cyl(207,220).
cyl(207,240).
cyl(208,224).
cyl(208,219).
cyl(209,217).
cyl(209,237).
cyl(210,232).
cyl(210,239).
cyl(211,235).
cyl(211,223).
cyl(212,228).
cyl(212,220).
cyl(213,229).
cyl(213,234).
cyl(214,230).
cyl(214,228).
cyl(215,223).
cyl(215,219).
cyl(216,221).
cyl(216,240).
cyl(217,243).
cyl(217,256).
cyl(218,246).
cyl(218,252).
cyl(219,250).
cyl(219,247).
cyl(220,257).
cyl(220,243).
cyl(221,245).
cyl(221,261).
cyl(222,254).
cyl(222,245).
cyl(223,258).
cyl(223,252).
cyl(224,244).
cyl(224,242).
cyl(225,253).
cyl(225,250).
cyl(226,263).
cyl(226,248).
cyl(227,251).
cyl(227,262).
cyl(228,249).
cyl(228,248).
cyl(229,258).
cyl(229,257).
cyl(230,258).
cyl(230,256).
cyl(231,262).
cyl(231,254).
cyl(232,242).
cyl(232,251).
cyl(233,244).
cyl(233,257).
cyl(234,256).
cyl(234,260).
cyl(235,262).
cyl(235,253).
cyl(236,259).
cyl(236,264).
cyl(237,261).
cyl(237,242).
cyl(238,260).
cyl(238,243).
cyl(239,260).
cyl(239,246).
cyl(240,254).
cyl(240,263).
cyl(241,265).
cyl(241,269).
cyl(242,283).
cyl(242,267).
cyl(243,270).
cyl(243,288).
cyl(244,280).
cyl(244,278).
cyl(245,271).
cyl(245,287).
cyl(246,284).
cyl(246,277).
cyl(247,288).
cyl(247,281).
cyl(248,280).
cyl(248,277).
cyl(249,273).
cyl(249,270).
cyl(250,277).
cyl(250,270).
cyl(251,286).
cyl(251,280).
cyl(252,279).
cyl(252,268).
cyl(253,283).
cyl(253,279).
cyl(254,277).
cyl(254,276).
cyl(255,265).
cyl(255,285).
cyl(256,277).
cyl(256,276).
cyl(257,284).
cyl(257,283).
cyl(258,270).
cyl(258,271).
cyl(259,277).
cyl(259,279).
cyl(260,284).
cyl(260,268).
cyl(261,267).
cyl(261,279).
cyl(262,271).
cyl(262,279).
cyl(263,268).
cyl(263,273).
cyl(264,272).
cyl(264,277).
cyl(265,297).
cyl(265,300).
cyl(266,302).
cyl(266,304).
cyl(267,292).
cyl(267,308).
cyl(268,296).
cyl(268,307).
cyl(269,306).
cyl(269,304).
cyl(270,300).
cyl(270,308).
cyl(271,293).
cyl(271,291).
cyl(272,294).
cyl(272,305).
cyl(273,293).
cyl(273,291).
cyl(274,303).
cyl(274,312).
cyl(275,294).
cyl(275,299).
cyl(276,292).
cyl(276,305).
cyl(277,303).
cyl(277,299).
cyl(278,297).
cyl(278,302).
cyl(279,302).
cyl(279,294).
cyl(280,291).
cyl(280,289).
cyl(281,294).
cyl(281,307).
cyl(282,293).
cyl(282,296).
cyl(283,308).
cyl(283,294).
cyl(284,302).
cyl(284,310).
cyl(285,289).
cyl(285,308).
cyl(286,292).
cyl(286,307).
cyl(287,293).
cyl(287,295).
cyl(288,296).
cyl(288,292).
cyl(289,322).
cyl(289,331).
cyl(290,333).
cyl(290,313).
cyl(291,326).
cyl(291,314).
cyl(292,334).
cyl(292,317).
cyl(293,317).
cyl(293,315).
cyl(294,333).
cyl(294,331).
cyl(295,321).
cyl(295,335).
cyl(296,314).
cyl(296,322).
cyl(297,321).
cyl(297,322).
cyl(298,332).
cyl(298,316).
cyl(299,321).
cyl(299,330).
cyl(300,320).
cyl(300,315).
cyl(301,317).
cyl(301,326).
cyl(302,335).
cyl(302,318).
cyl(303,336).
cyl(303,325).
cyl(304,325).
cyl(304,322).
cyl(305,332).
cyl(305,321).
cyl(306,335).
cyl(306,325).
cyl(307,323).
cyl(307,326).
cyl(308,316).
cyl(308,320).
cyl(309,321).
cyl(309,336).
cyl(310,322).
cyl(310,328).
cyl(311,332).
cyl(311,335).
cyl(312,332).
cyl(312,322).
cyl(313,359).
cyl(313,347).
cyl(314,348).
cyl(314,349).
cyl(315,350).
cyl(315,352).
cyl(316,351).
cyl(316,342).
cyl(317,354).
cyl(317,349).
cyl(318,340).
cyl(318,358).
cyl(319,359).
cyl(319,339).
cyl(320,357).
cyl(320,355).
cyl(321,357).
cyl(321,341).
cyl(322,344).
cyl(322,355).
cyl(323,340).
cyl(323,338).
cyl(324,342).
cyl(324,356).
cyl(325,355).
cyl(325,342).
cyl(326,345).
cyl(326,353).
cyl(327,345).
cyl(327,339).
cyl(328,360).
cyl(328,356).
cyl(329,358).
cyl(329,351).
cyl(330,359).
cyl(330,353).
cyl(331,341).
cyl(331,356).
cyl(332,344).
cyl(332,339).
cyl(333,351).
cyl(333,355).
cyl(334,355).
cyl(334,359).
cyl(335,350).
cyl(335,339).
cyl(336,342).
cyl(336,354).
cyl(337,365).
cyl(337,374).
cyl(338,364).
cyl(338,384).
cyl(339,373).
cyl(339,375).
cyl(340,380).
cyl(340,368).
cyl(341,372).
cyl(341,362).
cyl(342,368).
cyl(342,367).
cyl(343,364).
cyl(343,369).
cyl(344,382).
cyl(344,373).
cyl(345,367).
cyl(345,375).
cyl(346,370).
cyl(346,372).
cyl(347,363).
cyl(347,381).
cyl(348,371).
cyl(348,365).
cyl(349,372).
cyl(349,364).
cyl(350,379).
cyl(350,372).
cyl(351,381).
cyl(351,364).
cyl(352,381).
cyl(352,362).
cyl(353,370).
cyl(353,377).
cyl(354,373).
cyl(354,362).
cyl(355,367).
cyl(355,382).
cyl(356,370).
cyl(356,384).
cyl(357,371).
cyl(357,372).
cyl(358,361).
cyl(358,378).
cyl(359,371).
cyl(359,366).
cyl(360,382).
cyl(360,364).
cyl(361,407).
cyl(361,408).
cyl(362,392).
cyl(362,393).
cyl(363,393).
cyl(363,394).
cyl(364,387).
cyl(364,400).
cyl(365,397).
cyl(365,392).
cyl(366,400).
cyl(366,408).
cyl(367,401).
cyl(367,388).
cyl(368,389).
cyl(368,394).
cyl(369,388).
cyl(369,399).
cyl(370,405).
cyl(370,385).
cyl(371,398).
cyl(371,397).
cyl(372,404).
cyl(372,387).
cyl(373,404).
cyl(373,390).
cyl(374,396).
cyl(374,397).
cyl(375,401).
cyl(375,397).
cyl(376,399).
cyl(376,395).
cyl(377,397).
cyl(377,391).
cyl(378,392).
cyl(378,385).
cyl(379,390).
cyl(379,386).
cyl(380,408).
cyl(380,394).
cyl(381,398).
cyl(381,403).
cyl(382,385).
cyl(382,403).
cyl(383,385).
cyl(383,386).
cyl(384,397).
cyl(384,387).
cyl(385,418).
cyl(385,429).
cyl(386,419).
cyl(386,415).
cyl(387,413).
cyl(387,429).
cyl(388,415).
cyl(388,418).
cyl(389,429).
cyl(389,417).
cyl(390,417).
cyl(390,424).
cyl(391,409).
cyl(391,425).
cyl(392,418).
cyl(392,409).
cyl(393,428).
cyl(393,414).
cyl(394,427).
cyl(394,431).
cyl(395,429).
cyl(395,430).
cyl(396,418).
cyl(396,419).
cyl(397,432).
cyl(397,419).
cyl(398,420).
cyl(398,414).
cyl(399,419).
cyl(399,412).
cyl(400,415).
cyl(400,410).
cyl(401,420).
cyl(401,424).
cyl(402,426).
cyl(402,412).
cyl(403,431).
cyl(403,419).
cyl(404,428).
cyl(404,422).
cyl(405,417).
cyl(405,428).
cyl(406,422).
cyl(406,411).
cyl(407,424).
cyl(407,427).
cyl(408,410).
cyl(408,416).
cyl(409,436).
cyl(409,435).
cyl(410,442).
cyl(410,439).
cyl(411,456).
cyl(411,436).
cyl(412,449).
cyl(412,456).
cyl(413,453).
cyl(413,449).
cyl(414,440).
cyl(414,434).
cyl(415,436).
cyl(415,437).
cyl(416,433).
cyl(416,452).
cyl(417,433).
cyl(417,444).
cyl(418,436).
cyl(418,452).
cyl(419,445).
cyl(419,444).
cyl(420,451).
cyl(420,455).
cyl(421,439).
cyl(421,455).
cyl(422,445).
cyl(422,454).
cyl(423,456).
cyl(423,445).
cyl(424,445).
cyl(424,448).
cyl(425,434).
cyl(425,448).
cyl(426,442).
cyl(426,440).
cyl(427,437).
cyl(427,438).
cyl(428,453).
cyl(428,446).
cyl(429,437).
cyl(429,452).
cyl(430,444).
cyl(430,438).
cyl(431,449).
cyl(431,443).
cyl(432,442).
cyl(432,450).
cyl(433,469).
cyl(433,476).
cyl(434,476).
cyl(434,479).
cyl(435,478).
cyl(435,461).
cyl(436,467).
cyl(436,471).
cyl(437,479).
cyl(437,468).
cyl(438,474).
cyl(438,467).
cyl(439,459).
cyl(439,473).
cyl(440,458).
cyl(440,459).
cyl(441,467).
cyl(441,458).
cyl(442,470).
cyl(442,472).
cyl(443,477).
cyl(443,460).
cyl(444,475).
cyl(444,474).
cyl(445,471).
cyl(445,480).
cyl(446,477).
cyl(446,474).
cyl(447,472).
cyl(447,476).
cyl(448,469).
cyl(448,474).
cyl(449,465).
cyl(449,471).
cyl(450,465).
cyl(450,459).
cyl(451,458).
cyl(451,475).
cyl(452,457).
cyl(452,462).
cyl(453,478).
cyl(453,459).
cyl(454,472).
cyl(454,461).
cyl(455,469).
cyl(455,479).
cyl(456,457).
cyl(456,458).
cyl(457,482).
cyl(457,500).
cyl(458,492).
cyl(458,488).
cyl(459,488).
cyl(459,489).
cyl(460,483).
cyl(460,500).
cyl(461,504).
cyl(461,486).
cyl(462,491).
cyl(462,492).
cyl(463,499).
cyl(463,493).
cyl(464,483).
cyl(464,502).
cyl(465,495).
cyl(465,502).
cyl(466,483).
cyl(466,487).
cyl(467,491).
cyl(467,503).
cyl(468,492).
cyl(468,498).
cyl(469,501).
cyl(469,504).
cyl(470,484).
cyl(470,487).
cyl(471,502).
cyl(471,487).
cyl(472,499).
cyl(472,490).
cyl(473,500).
cyl(473,495).
cyl(474,481).
cyl(474,487).
cyl(475,488).
cyl(475,494).
cyl(476,488).
cyl(476,500).
cyl(477,492).
cyl(477,489).
cyl(478,504).
cyl(478,481).
cyl(479,502).
cyl(479,491).
cyl(480,497).
cyl(480,487).
cyl(481,528).
cyl(481,522).
cyl(482,522).
cyl(482,520).
cyl(483,516).
cyl(483,515).
cyl(484,526).
cyl(484,514).
cyl(485,511).
cyl(485,508).
cyl(486,512).
cyl(486,524).
cyl(487,525).
cyl(487,520).
cyl(488,508).
cyl(488,520).
cyl(489,526).
cyl(489,527).
cyl(490,517).
cyl(490,505).
cyl(491,514).
cyl(491,512).
cyl(492,524).
cyl(492,522).
cyl(493,524).
cyl(493,517).
cyl(494,520).
cyl(494,518).
cyl(495,516).
cyl(495,508).
cyl(496,508).
cyl(496,525).
cyl(497,523).
cyl(497,505).
cyl(498,507).
cyl(498,505).
cyl(499,510).
cyl(499,523).
cyl(500,522).
cyl(500,518).
cyl(501,511).
cyl(501,517).
cyl(502,506).
cyl(502,513).
cyl(503,505).
cyl(503,514).
cyl(504,525).
cyl(504,519).
cyl(505,547).
cyl(505,534).
cyl(506,551).
cyl(506,538).
cyl(507,538).
cyl(507,530).
cyl(508,551).
cyl(508,544).
cyl(509,550).
cyl(509,551).
cyl(510,529).
cyl(510,539).
cyl(511,544).
cyl(511,549).
cyl(512,543).
cyl(512,549).
cyl(513,540).
cyl(513,533).
cyl(514,551).
cyl(514,550).
cyl(515,536).
cyl(515,547).
cyl(516,544).
cyl(516,531).
cyl(517,535).
cyl(517,549).
cyl(518,546).
cyl(518,542).
cyl(519,537).
cyl(519,547).
cyl(520,547).
cyl(520,544).
cyl(521,531).
cyl(521,544).
cyl(522,533).
cyl(522,530).
cyl(523,538).
cyl(523,546).
cyl(524,541).
cyl(524,531).
cyl(525,530).
cyl(525,533).
cyl(526,530).
cyl(526,529).
cyl(527,550).
cyl(527,529).
cyl(528,541).
cyl(528,534).
cyl(529,564).
cyl(529,574).
cyl(530,554).
cyl(530,564).
cyl(531,564).
cyl(531,556).
cyl(532,569).
cyl(532,554).
cyl(533,561).
cyl(533,566).
cyl(534,565).
cyl(534,576).
cyl(535,570).
cyl(535,558).
cyl(536,572).
cyl(536,571).
cyl(537,555).
cyl(537,569).
cyl(538,564).
cyl(538,555).
cyl(539,558).
cyl(539,566).
cyl(540,571).
cyl(540,576).
cyl(541,567).
cyl(541,561).
cyl(542,573).
cyl(542,570).
cyl(543,576).
cyl(543,565).
cyl(544,572).
cyl(544,565).
cyl(545,553).
cyl(545,554).
cyl(546,556).
cyl(546,574).
cyl(547,553).
cyl(547,575).
cyl(548,571).
cyl(548,573).
cyl(549,556).
cyl(549,574).
cyl(550,575).
cyl(550,555).
cyl(551,558).
cyl(551,569).
cyl(552,569).
cyl(552,564).

:- pred acyl(int::in, int::out) is nondet.

acyl(30,1).
acyl(40,1).
acyl(43,2).
acyl(34,2).
acyl(30,3).
acyl(33,3).
acyl(45,4).
acyl(40,4).
acyl(31,5).
acyl(45,5).
acyl(31,6).
acyl(48,6).
acyl(31,7).
acyl(41,7).
acyl(25,8).
acyl(30,8).
acyl(40,9).
acyl(31,9).
acyl(35,10).
acyl(46,10).
acyl(32,11).
acyl(28,11).
acyl(35,12).
acyl(43,12).
acyl(46,13).
acyl(48,13).
acyl(39,14).
acyl(35,14).
acyl(46,15).
acyl(28,15).
acyl(28,16).
acyl(42,16).
acyl(33,17).
acyl(25,17).
acyl(46,18).
acyl(27,18).
acyl(38,19).
acyl(47,19).
acyl(27,20).
acyl(41,20).
acyl(34,21).
acyl(38,21).
acyl(27,22).
acyl(33,22).
acyl(26,23).
acyl(35,23).
acyl(36,24).
acyl(25,24).
acyl(70,25).
acyl(52,25).
acyl(59,26).
acyl(71,26).
acyl(61,27).
acyl(58,27).
acyl(61,28).
acyl(54,28).
acyl(63,29).
acyl(70,29).
acyl(58,30).
acyl(53,30).
acyl(56,31).
acyl(60,31).
acyl(58,32).
acyl(50,32).
acyl(62,33).
acyl(66,33).
acyl(55,34).
acyl(72,34).
acyl(63,35).
acyl(58,35).
acyl(55,36).
acyl(64,36).
acyl(56,37).
acyl(58,37).
acyl(68,38).
acyl(61,38).
acyl(64,39).
acyl(52,39).
acyl(57,40).
acyl(70,40).
acyl(69,41).
acyl(55,41).
acyl(62,42).
acyl(53,42).
acyl(68,43).
acyl(65,43).
acyl(56,44).
acyl(62,44).
acyl(67,45).
acyl(71,45).
acyl(71,46).
acyl(66,46).
acyl(61,47).
acyl(60,47).
acyl(60,48).
acyl(54,48).
acyl(93,49).
acyl(88,49).
acyl(90,50).
acyl(93,50).
acyl(95,51).
acyl(92,51).
acyl(93,52).
acyl(94,52).
acyl(83,53).
acyl(90,53).
acyl(78,54).
acyl(79,54).
acyl(79,55).
acyl(92,55).
acyl(96,56).
acyl(94,56).
acyl(94,57).
acyl(80,57).
acyl(79,58).
acyl(83,58).
acyl(75,59).
acyl(96,59).
acyl(86,60).
acyl(79,60).
acyl(85,61).
acyl(75,61).
acyl(82,62).
acyl(95,62).
acyl(85,63).
acyl(78,63).
acyl(92,64).
acyl(86,64).
acyl(76,65).
acyl(78,65).
acyl(78,66).
acyl(81,66).
acyl(96,67).
acyl(78,67).
acyl(88,68).
acyl(77,68).
acyl(86,69).
acyl(90,69).
acyl(93,70).
acyl(80,70).
acyl(92,71).
acyl(74,71).
acyl(88,72).
acyl(81,72).
acyl(113,73).
acyl(116,73).
acyl(101,74).
acyl(100,74).
acyl(113,75).
acyl(109,75).
acyl(112,76).
acyl(98,76).
acyl(109,77).
acyl(108,77).
acyl(112,78).
acyl(117,78).
acyl(101,79).
acyl(110,79).
acyl(110,80).
acyl(119,80).
acyl(108,81).
acyl(98,81).
acyl(111,82).
acyl(113,82).
acyl(116,83).
acyl(111,83).
acyl(114,84).
acyl(103,84).
acyl(97,85).
acyl(114,85).
acyl(107,86).
acyl(120,86).
acyl(116,87).
acyl(105,87).
acyl(99,88).
acyl(105,88).
acyl(118,89).
acyl(110,89).
acyl(104,90).
acyl(108,90).
acyl(98,91).
acyl(106,91).
acyl(100,92).
acyl(108,92).
acyl(117,93).
acyl(114,93).
acyl(115,94).
acyl(118,94).
acyl(99,95).
acyl(108,95).
acyl(111,96).
acyl(98,96).
acyl(125,97).
acyl(132,97).
acyl(134,98).
acyl(131,98).
acyl(124,99).
acyl(136,99).
acyl(122,100).
acyl(129,100).
acyl(140,101).
acyl(125,101).
acyl(142,102).
acyl(137,102).
acyl(137,103).
acyl(141,103).
acyl(135,104).
acyl(132,104).
acyl(126,105).
acyl(137,105).
acyl(142,106).
acyl(128,106).
acyl(123,107).
acyl(143,107).
acyl(126,108).
acyl(132,108).
acyl(128,109).
acyl(130,109).
acyl(124,110).
acyl(136,110).
acyl(123,111).
acyl(141,111).
acyl(128,112).
acyl(142,112).
acyl(130,113).
acyl(128,113).
acyl(144,114).
acyl(139,114).
acyl(141,115).
acyl(139,115).
acyl(134,116).
acyl(126,116).
acyl(135,117).
acyl(131,117).
acyl(137,118).
acyl(142,118).
acyl(133,119).
acyl(125,119).
acyl(135,120).
acyl(139,120).
acyl(154,121).
acyl(151,121).
acyl(150,122).
acyl(156,122).
acyl(158,123).
acyl(168,123).
acyl(160,124).
acyl(168,124).
acyl(159,125).
acyl(161,125).
acyl(167,126).
acyl(156,126).
acyl(151,127).
acyl(167,127).
acyl(164,128).
acyl(152,128).
acyl(154,129).
acyl(158,129).
acyl(164,130).
acyl(150,130).
acyl(165,131).
acyl(155,131).
acyl(154,132).
acyl(157,132).
acyl(163,133).
acyl(161,133).
acyl(147,134).
acyl(160,134).
acyl(156,135).
acyl(148,135).
acyl(153,136).
acyl(157,136).
acyl(159,137).
acyl(152,137).
acyl(149,138).
acyl(152,138).
acyl(161,139).
acyl(157,139).
acyl(167,140).
acyl(161,140).
acyl(168,141).
acyl(145,141).
acyl(161,142).
acyl(160,142).
acyl(146,143).
acyl(150,143).
acyl(160,144).
acyl(163,144).
acyl(184,145).
acyl(171,145).
acyl(187,146).
acyl(171,146).
acyl(179,147).
acyl(182,147).
acyl(185,148).
acyl(180,148).
acyl(187,149).
acyl(174,149).
acyl(175,150).
acyl(190,150).
acyl(176,151).
acyl(185,151).
acyl(169,152).
acyl(182,152).
acyl(181,153).
acyl(188,153).
acyl(190,154).
acyl(179,154).
acyl(184,155).
acyl(187,155).
acyl(169,156).
acyl(184,156).
acyl(183,157).
acyl(186,157).
acyl(174,158).
acyl(179,158).
acyl(175,159).
acyl(172,159).
acyl(190,160).
acyl(189,160).
acyl(180,161).
acyl(175,161).
acyl(192,162).
acyl(182,162).
acyl(179,163).
acyl(175,163).
acyl(174,164).
acyl(181,164).
acyl(178,165).
acyl(185,165).
acyl(170,166).
acyl(169,166).
acyl(183,167).
acyl(178,167).
acyl(180,168).
acyl(181,168).
acyl(213,169).
acyl(207,169).
acyl(206,170).
acyl(203,170).
acyl(195,171).
acyl(209,171).
acyl(214,172).
acyl(197,172).
acyl(205,173).
acyl(206,173).
acyl(212,174).
acyl(214,174).
acyl(201,175).
acyl(204,175).
acyl(206,176).
acyl(200,176).
acyl(202,177).
acyl(207,177).
acyl(202,178).
acyl(203,178).
acyl(216,179).
acyl(196,179).
acyl(211,180).
acyl(197,180).
acyl(193,181).
acyl(207,181).
acyl(196,182).
acyl(194,182).
acyl(215,183).
acyl(199,183).
acyl(203,184).
acyl(204,184).
acyl(196,185).
acyl(208,185).
acyl(195,186).
acyl(212,186).
acyl(193,187).
acyl(194,187).
acyl(204,188).
acyl(200,188).
acyl(205,189).
acyl(201,189).
acyl(210,190).
acyl(194,190).
acyl(193,191).
acyl(209,191).
acyl(208,192).
acyl(209,192).
acyl(227,193).
acyl(223,193).
acyl(240,194).
acyl(227,194).
acyl(239,195).
acyl(230,195).
acyl(228,196).
acyl(230,196).
acyl(234,197).
acyl(221,197).
acyl(240,198).
acyl(222,198).
acyl(221,199).
acyl(235,199).
acyl(230,200).
acyl(235,200).
acyl(230,201).
acyl(225,201).
acyl(238,202).
acyl(217,202).
acyl(224,203).
acyl(217,203).
acyl(221,204).
acyl(234,204).
acyl(228,205).
acyl(217,205).
acyl(221,206).
acyl(230,206).
acyl(220,207).
acyl(240,207).
acyl(224,208).
acyl(219,208).
acyl(217,209).
acyl(237,209).
acyl(232,210).
acyl(239,210).
acyl(235,211).
acyl(223,211).
acyl(228,212).
acyl(220,212).
acyl(229,213).
acyl(234,213).
acyl(230,214).
acyl(228,214).
acyl(223,215).
acyl(219,215).
acyl(221,216).
acyl(240,216).
acyl(243,217).
acyl(256,217).
acyl(246,218).
acyl(252,218).
acyl(250,219).
acyl(247,219).
acyl(257,220).
acyl(243,220).
acyl(245,221).
acyl(261,221).
acyl(254,222).
acyl(245,222).
acyl(258,223).
acyl(252,223).
acyl(244,224).
acyl(242,224).
acyl(253,225).
acyl(250,225).
acyl(263,226).
acyl(248,226).
acyl(251,227).
acyl(262,227).
acyl(249,228).
acyl(248,228).
acyl(258,229).
acyl(257,229).
acyl(258,230).
acyl(256,230).
acyl(262,231).
acyl(254,231).
acyl(242,232).
acyl(251,232).
acyl(244,233).
acyl(257,233).
acyl(256,234).
acyl(260,234).
acyl(262,235).
acyl(253,235).
acyl(259,236).
acyl(264,236).
acyl(261,237).
acyl(242,237).
acyl(260,238).
acyl(243,238).
acyl(260,239).
acyl(246,239).
acyl(254,240).
acyl(263,240).
acyl(265,241).
acyl(269,241).
acyl(283,242).
acyl(267,242).
acyl(270,243).
acyl(288,243).
acyl(280,244).
acyl(278,244).
acyl(271,245).
acyl(287,245).
acyl(284,246).
acyl(277,246).
acyl(288,247).
acyl(281,247).
acyl(280,248).
acyl(277,248).
acyl(273,249).
acyl(270,249).
acyl(277,250).
acyl(270,250).
acyl(286,251).
acyl(280,251).
acyl(279,252).
acyl(268,252).
acyl(283,253).
acyl(279,253).
acyl(277,254).
acyl(276,254).
acyl(265,255).
acyl(285,255).
acyl(277,256).
acyl(276,256).
acyl(284,257).
acyl(283,257).
acyl(270,258).
acyl(271,258).
acyl(277,259).
acyl(279,259).
acyl(284,260).
acyl(268,260).
acyl(267,261).
acyl(279,261).
acyl(271,262).
acyl(279,262).
acyl(268,263).
acyl(273,263).
acyl(272,264).
acyl(277,264).
acyl(297,265).
acyl(300,265).
acyl(302,266).
acyl(304,266).
acyl(292,267).
acyl(308,267).
acyl(296,268).
acyl(307,268).
acyl(306,269).
acyl(304,269).
acyl(300,270).
acyl(308,270).
acyl(293,271).
acyl(291,271).
acyl(294,272).
acyl(305,272).
acyl(293,273).
acyl(291,273).
acyl(303,274).
acyl(312,274).
acyl(294,275).
acyl(299,275).
acyl(292,276).
acyl(305,276).
acyl(303,277).
acyl(299,277).
acyl(297,278).
acyl(302,278).
acyl(302,279).
acyl(294,279).
acyl(291,280).
acyl(289,280).
acyl(294,281).
acyl(307,281).
acyl(293,282).
acyl(296,282).
acyl(308,283).
acyl(294,283).
acyl(302,284).
acyl(310,284).
acyl(289,285).
acyl(308,285).
acyl(292,286).
acyl(307,286).
acyl(293,287).
acyl(295,287).
acyl(296,288).
acyl(292,288).
acyl(322,289).
acyl(331,289).
acyl(333,290).
acyl(313,290).
acyl(326,291).
acyl(314,291).
acyl(334,292).
acyl(317,292).
acyl(317,293).
acyl(315,293).
acyl(333,294).
acyl(331,294).
acyl(321,295).
acyl(335,295).
acyl(314,296).
acyl(322,296).
acyl(321,297).
acyl(322,297).
acyl(332,298).
acyl(316,298).
acyl(321,299).
acyl(330,299).
acyl(320,300).
acyl(315,300).
acyl(317,301).
acyl(326,301).
acyl(335,302).
acyl(318,302).
acyl(336,303).
acyl(325,303).
acyl(325,304).
acyl(322,304).
acyl(332,305).
acyl(321,305).
acyl(335,306).
acyl(325,306).
acyl(323,307).
acyl(326,307).
acyl(316,308).
acyl(320,308).
acyl(321,309).
acyl(336,309).
acyl(322,310).
acyl(328,310).
acyl(332,311).
acyl(335,311).
acyl(332,312).
acyl(322,312).
acyl(359,313).
acyl(347,313).
acyl(348,314).
acyl(349,314).
acyl(350,315).
acyl(352,315).
acyl(351,316).
acyl(342,316).
acyl(354,317).
acyl(349,317).
acyl(340,318).
acyl(358,318).
acyl(359,319).
acyl(339,319).
acyl(357,320).
acyl(355,320).
acyl(357,321).
acyl(341,321).
acyl(344,322).
acyl(355,322).
acyl(340,323).
acyl(338,323).
acyl(342,324).
acyl(356,324).
acyl(355,325).
acyl(342,325).
acyl(345,326).
acyl(353,326).
acyl(345,327).
acyl(339,327).
acyl(360,328).
acyl(356,328).
acyl(358,329).
acyl(351,329).
acyl(359,330).
acyl(353,330).
acyl(341,331).
acyl(356,331).
acyl(344,332).
acyl(339,332).
acyl(351,333).
acyl(355,333).
acyl(355,334).
acyl(359,334).
acyl(350,335).
acyl(339,335).
acyl(342,336).
acyl(354,336).
acyl(365,337).
acyl(374,337).
acyl(364,338).
acyl(384,338).
acyl(373,339).
acyl(375,339).
acyl(380,340).
acyl(368,340).
acyl(372,341).
acyl(362,341).
acyl(368,342).
acyl(367,342).
acyl(364,343).
acyl(369,343).
acyl(382,344).
acyl(373,344).
acyl(367,345).
acyl(375,345).
acyl(370,346).
acyl(372,346).
acyl(363,347).
acyl(381,347).
acyl(371,348).
acyl(365,348).
acyl(372,349).
acyl(364,349).
acyl(379,350).
acyl(372,350).
acyl(381,351).
acyl(364,351).
acyl(381,352).
acyl(362,352).
acyl(370,353).
acyl(377,353).
acyl(373,354).
acyl(362,354).
acyl(367,355).
acyl(382,355).
acyl(370,356).
acyl(384,356).
acyl(371,357).
acyl(372,357).
acyl(361,358).
acyl(378,358).
acyl(371,359).
acyl(366,359).
acyl(382,360).
acyl(364,360).
acyl(407,361).
acyl(408,361).
acyl(392,362).
acyl(393,362).
acyl(393,363).
acyl(394,363).
acyl(387,364).
acyl(400,364).
acyl(397,365).
acyl(392,365).
acyl(400,366).
acyl(408,366).
acyl(401,367).
acyl(388,367).
acyl(389,368).
acyl(394,368).
acyl(388,369).
acyl(399,369).
acyl(405,370).
acyl(385,370).
acyl(398,371).
acyl(397,371).
acyl(404,372).
acyl(387,372).
acyl(404,373).
acyl(390,373).
acyl(396,374).
acyl(397,374).
acyl(401,375).
acyl(397,375).
acyl(399,376).
acyl(395,376).
acyl(397,377).
acyl(391,377).
acyl(392,378).
acyl(385,378).
acyl(390,379).
acyl(386,379).
acyl(408,380).
acyl(394,380).
acyl(398,381).
acyl(403,381).
acyl(385,382).
acyl(403,382).
acyl(385,383).
acyl(386,383).
acyl(397,384).
acyl(387,384).
acyl(418,385).
acyl(429,385).
acyl(419,386).
acyl(415,386).
acyl(413,387).
acyl(429,387).
acyl(415,388).
acyl(418,388).
acyl(429,389).
acyl(417,389).
acyl(417,390).
acyl(424,390).
acyl(409,391).
acyl(425,391).
acyl(418,392).
acyl(409,392).
acyl(428,393).
acyl(414,393).
acyl(427,394).
acyl(431,394).
acyl(429,395).
acyl(430,395).
acyl(418,396).
acyl(419,396).
acyl(432,397).
acyl(419,397).
acyl(420,398).
acyl(414,398).
acyl(419,399).
acyl(412,399).
acyl(415,400).
acyl(410,400).
acyl(420,401).
acyl(424,401).
acyl(426,402).
acyl(412,402).
acyl(431,403).
acyl(419,403).
acyl(428,404).
acyl(422,404).
acyl(417,405).
acyl(428,405).
acyl(422,406).
acyl(411,406).
acyl(424,407).
acyl(427,407).
acyl(410,408).
acyl(416,408).
acyl(436,409).
acyl(435,409).
acyl(442,410).
acyl(439,410).
acyl(456,411).
acyl(436,411).
acyl(449,412).
acyl(456,412).
acyl(453,413).
acyl(449,413).
acyl(440,414).
acyl(434,414).
acyl(436,415).
acyl(437,415).
acyl(433,416).
acyl(452,416).
acyl(433,417).
acyl(444,417).
acyl(436,418).
acyl(452,418).
acyl(445,419).
acyl(444,419).
acyl(451,420).
acyl(455,420).
acyl(439,421).
acyl(455,421).
acyl(445,422).
acyl(454,422).
acyl(456,423).
acyl(445,423).
acyl(445,424).
acyl(448,424).
acyl(434,425).
acyl(448,425).
acyl(442,426).
acyl(440,426).
acyl(437,427).
acyl(438,427).
acyl(453,428).
acyl(446,428).
acyl(437,429).
acyl(452,429).
acyl(444,430).
acyl(438,430).
acyl(449,431).
acyl(443,431).
acyl(442,432).
acyl(450,432).
acyl(469,433).
acyl(476,433).
acyl(476,434).
acyl(479,434).
acyl(478,435).
acyl(461,435).
acyl(467,436).
acyl(471,436).
acyl(479,437).
acyl(468,437).
acyl(474,438).
acyl(467,438).
acyl(459,439).
acyl(473,439).
acyl(458,440).
acyl(459,440).
acyl(467,441).
acyl(458,441).
acyl(470,442).
acyl(472,442).
acyl(477,443).
acyl(460,443).
acyl(475,444).
acyl(474,444).
acyl(471,445).
acyl(480,445).
acyl(477,446).
acyl(474,446).
acyl(472,447).
acyl(476,447).
acyl(469,448).
acyl(474,448).
acyl(465,449).
acyl(471,449).
acyl(465,450).
acyl(459,450).
acyl(458,451).
acyl(475,451).
acyl(457,452).
acyl(462,452).
acyl(478,453).
acyl(459,453).
acyl(472,454).
acyl(461,454).
acyl(469,455).
acyl(479,455).
acyl(457,456).
acyl(458,456).
acyl(482,457).
acyl(500,457).
acyl(492,458).
acyl(488,458).
acyl(488,459).
acyl(489,459).
acyl(483,460).
acyl(500,460).
acyl(504,461).
acyl(486,461).
acyl(491,462).
acyl(492,462).
acyl(499,463).
acyl(493,463).
acyl(483,464).
acyl(502,464).
acyl(495,465).
acyl(502,465).
acyl(483,466).
acyl(487,466).
acyl(491,467).
acyl(503,467).
acyl(492,468).
acyl(498,468).
acyl(501,469).
acyl(504,469).
acyl(484,470).
acyl(487,470).
acyl(502,471).
acyl(487,471).
acyl(499,472).
acyl(490,472).
acyl(500,473).
acyl(495,473).
acyl(481,474).
acyl(487,474).
acyl(488,475).
acyl(494,475).
acyl(488,476).
acyl(500,476).
acyl(492,477).
acyl(489,477).
acyl(504,478).
acyl(481,478).
acyl(502,479).
acyl(491,479).
acyl(497,480).
acyl(487,480).
acyl(528,481).
acyl(522,481).
acyl(522,482).
acyl(520,482).
acyl(516,483).
acyl(515,483).
acyl(526,484).
acyl(514,484).
acyl(511,485).
acyl(508,485).
acyl(512,486).
acyl(524,486).
acyl(525,487).
acyl(520,487).
acyl(508,488).
acyl(520,488).
acyl(526,489).
acyl(527,489).
acyl(517,490).
acyl(505,490).
acyl(514,491).
acyl(512,491).
acyl(524,492).
acyl(522,492).
acyl(524,493).
acyl(517,493).
acyl(520,494).
acyl(518,494).
acyl(516,495).
acyl(508,495).
acyl(508,496).
acyl(525,496).
acyl(523,497).
acyl(505,497).
acyl(507,498).
acyl(505,498).
acyl(510,499).
acyl(523,499).
acyl(522,500).
acyl(518,500).
acyl(511,501).
acyl(517,501).
acyl(506,502).
acyl(513,502).
acyl(505,503).
acyl(514,503).
acyl(525,504).
acyl(519,504).
acyl(547,505).
acyl(534,505).
acyl(551,506).
acyl(538,506).
acyl(538,507).
acyl(530,507).
acyl(551,508).
acyl(544,508).
acyl(550,509).
acyl(551,509).
acyl(529,510).
acyl(539,510).
acyl(544,511).
acyl(549,511).
acyl(543,512).
acyl(549,512).
acyl(540,513).
acyl(533,513).
acyl(551,514).
acyl(550,514).
acyl(536,515).
acyl(547,515).
acyl(544,516).
acyl(531,516).
acyl(535,517).
acyl(549,517).
acyl(546,518).
acyl(542,518).
acyl(537,519).
acyl(547,519).
acyl(547,520).
acyl(544,520).
acyl(531,521).
acyl(544,521).
acyl(533,522).
acyl(530,522).
acyl(538,523).
acyl(546,523).
acyl(541,524).
acyl(531,524).
acyl(530,525).
acyl(533,525).
acyl(530,526).
acyl(529,526).
acyl(550,527).
acyl(529,527).
acyl(541,528).
acyl(534,528).
acyl(564,529).
acyl(574,529).
acyl(554,530).
acyl(564,530).
acyl(564,531).
acyl(556,531).
acyl(569,532).
acyl(554,532).
acyl(561,533).
acyl(566,533).
acyl(565,534).
acyl(576,534).
acyl(570,535).
acyl(558,535).
acyl(572,536).
acyl(571,536).
acyl(555,537).
acyl(569,537).
acyl(564,538).
acyl(555,538).
acyl(558,539).
acyl(566,539).
acyl(571,540).
acyl(576,540).
acyl(567,541).
acyl(561,541).
acyl(573,542).
acyl(570,542).
acyl(576,543).
acyl(565,543).
acyl(572,544).
acyl(565,544).
acyl(553,545).
acyl(554,545).
acyl(556,546).
acyl(574,546).
acyl(553,547).
acyl(575,547).
acyl(571,548).
acyl(573,548).
acyl(556,549).
acyl(574,549).
acyl(575,550).
acyl(555,550).
acyl(558,551).
acyl(569,551).
acyl(569,552).
acyl(564,552).
