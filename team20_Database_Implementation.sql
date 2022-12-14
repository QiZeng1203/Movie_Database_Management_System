-- team 20 database implementation
USE team20;

DROP TABLE IF EXISTS Rating;
DROP TABLE IF EXISTS MovieAward;
DROP TABLE IF EXISTS MovieGenre;
DROP TABLE IF EXISTS MovieActor;
DROP TABLE IF EXISTS MovieProduction;

DROP TABLE IF EXISTS Award;
DROP TABLE IF EXISTS Reviewer;
DROP TABLE IF EXISTS Actor;
DROP TABLE IF EXISTS ProductionCompany;
DROP TABLE IF EXISTS Genre;
DROP TABLE IF EXISTS Movie;
DROP TABLE IF EXISTS Director;
DROP TABLE IF EXISTS Actor;
DROP TABLE IF EXISTS Person;


CREATE TABLE dbo.Person
	(
	PersonID VARCHAR(10)  NOT NULL PRIMARY KEY,
	PersonFirstName varchar(40),
	PersonLastName varchar(40),
	DateOfBirth date,
	Gender varchar(40),
	Nationality varchar(40)
	);
	
CREATE TABLE dbo.Director
	(
	DirectorID VARCHAR(10) NOT NULL PRIMARY KEY,
		FOREIGN KEY (DirectorID) REFERENCES dbo.Person(PersonID),
	DirectorBio varchar(100)
	);

CREATE TABLE dbo.Actor
    (
	 ActorID VARCHAR(10) NOT NULL PRIMARY KEY,
		FOREIGN KEY (ActorID) REFERENCES dbo.Person(PersonID),
	 ActorBIO VARCHAR(100)
    );

CREATE TABLE dbo.Movie
	(
	MovieID VARCHAR(10) NOT NULL PRIMARY KEY,
	DirectorID VARCHAR(10) 
		REFERENCES dbo.Director(DirectorID),
	MovieTitle varchar(40) NOT NULL,
	ReleaseDate date,
	RunningTime time,
	Language varchar(40) NOT NULL,
	Country varchar(40) NOT NULL
	);

CREATE TABLE dbo.Genre
	(
	GenreID VARCHAR(10) NOT NULL PRIMARY KEY,
	GenreName varchar(40)
	);
	
CREATE TABLE dbo.MovieGenre
	(
	MovieID VARCHAR(10) NOT NULL
		REFERENCES dbo.Movie(MovieID),
	GenreID VARCHAR(10) NOT NULL
		REFERENCES dbo.Genre(GenreID)
	CONSTRAINT PKMovieGenre PRIMARY KEY CLUSTERED
             (MovieID, GenreID)
	);

CREATE TABLE dbo.ProductionCompany
	(
	ProductionCompanyID VARCHAR(10) NOT NULL PRIMARY KEY,
	ProductionCompanyName varchar(40) NOT NULL,
	District varchar(40) NOT NULL,
	City varchar(40) NOT NULL,
	State varchar(40) NOT NULL,
	PostalCode int NOT NULL,
	Country varchar(40) NOT NULL
	);

CREATE TABLE dbo.MovieProduction
	(
	MovieID VARCHAR(10) NOT NULL
		REFERENCES dbo.Movie(MovieID),
	ProductionCompanyID VARCHAR(10) NOT NULL
		REFERENCES dbo.ProductionCompany(ProductionCompanyID)
	CONSTRAINT PKMovieProduction PRIMARY KEY CLUSTERED
             (MovieID, ProductionCompanyID)
	);

CREATE TABLE dbo.MovieActor
    (
    RoleID VARCHAR(10) NOT NULL PRIMARY KEY,
 	MovieID VARCHAR(10) NOT NULL REFERENCES dbo.Movie(MovieID),
 	ActorID VARCHAR(10) NOT NULL REFERENCES dbo.Actor(ActorID),
 	RoleName VARCHAR(40) NOT NULL,
 	RoleDescription VARCHAR(100),
 	CONSTRAINT role_info UNIQUE(MovieID, ActorID, RoleName)
 	);
 
CREATE TABLE dbo.Award
(
    AwardID varchar(10) NOT NULL PRIMARY KEY,
    AwardName varchar(MAX) NOT NULL,
    AwardDescription varchar(MAX) NOT NULL
);

CREATE TABLE dbo.MovieAward
(
    Movie_AwardID varchar(10) PRIMARY KEY,
    AwardID varchar(10) NOT NULL REFERENCES dbo.Award(AwardID),
    MovieID varchar(10) NOT NULL REFERENCES dbo.Movie(MovieID),
    IssueDate DATE,
    CONSTRAINT award_movie_info UNIQUE(AwardID, MovieID, IssueDate)
);

CREATE table dbo.Reviewer
(
 ReviewerID varchar(10) not null primary key references dbo.Person(PersonID),
 Email varchar(256) not null,
 
)

create table dbo.Rating
(
 MovieID varchar(10) not null references dbo.Movie(MovieID),
 ReviewerID varchar(10) not null references dbo.Reviewer(ReviewerID),
 Stars int not null,
 Comment varchar(1000) not null,
 CreateDate date not null,
 ModifyDate date not null,
 constraint PKItem primary key clustered (MovieID, ReviewerID)
)

go;

--encryptTrigger
CREATE MASTER KEY
ENCRYPTION BY PASSWORD = 'Email_P@sswOrd';

CREATE CERTIFICATE TestCertificate
WITH SUBJECT = 'Reviewer Email Adress',
EXPIRY_DATE = '2026-10-31';

CREATE SYMMETRIC KEY TestSymmetricKey
WITH ALGORITHM = AES_128
ENCRYPTION BY CERTIFICATE TestCertificate;

OPEN SYMMETRIC KEY TestSymmetricKey 
DECRYPTION BY CERTIFICATE TestCertificate; 

create trigger EncryptEmail on dbo.Reviewer 
for insert, update
as
begin 
	if UPDATE(Email)
	Begin 
		declare @id varchar(10)
		declare @Email varchar(256)
		select @Email = [Email], @id = ReviewerID from inserted
		SET @Email = EncryptByKey(Key_GUID('TestSymmetricKey'), @Email);  
		update dbo.Reviewer 
		set Email = @Email
		where ReviewerID = @id
	END 
end;

-- view for the top 3 actors in the number of movies he/she has casted in 
drop view if exists ActorCastRankWithTies;

go;

create view ActorCastRankWithTies
as
select p.PersonFirstName, p.PersonLastName, p.DateOfBirth, p.Gender, p.Nationality  
from
(select a.ActorID , rank() over(order by count(a.ActorID) desc) as "Rank"
from Movie m 
inner join MovieActor ma 
on ma.MovieID = m.MovieID 
inner join Actor a 
on a.ActorID = ma.ActorID 
group by a.ActorID) as t1
inner join Person p 
on t1.ActorID = p.PersonID 
where t1.Rank < 4;

--view for the top3 review movie
drop view if exists topReviewMovie;

go;

create view topReviewMovie(MovieID, MovieTitle,ReleaseDate, TotalRates, AvgRating) 
as 
select 
       r.movieid,  
       m.MovieTitle, 
       m.releaseDate,
       count(*) [cnt], 
       ROUND(avg(CAST(r.Stars as float)),1 ) 
       
from rating r join movie m on m.MovieID  = r.MovieID

group by r.MovieID, m.MovieTitle, m.releasedate
order by cnt desc
offset 0 ROWs 
fetch first 3 rows only;


-- table level constraints for checking correct genre type inputed
ALTER TABLE dbo.MovieGenre DROP CONSTRAINT IF EXISTS MovieGenreInput;
GO
DROP FUNCTION if exists CheckGenreType;
GO
CREATE FUNCTION CheckGenreType (@GenreType VARCHAR(40))
RETURNS SMALLINT
AS
BEGIN
    DECLARE @Flag SMALLINT;
    IF @GenreType NOT IN ('G01', 'G02', 'G03', 'G04', 'G05', 'G06', 'G07', 'G08', 'G09', 'G10')
        SET @Flag = 1
    ELSE
        SET @Flag = 0

    RETURN @Flag
END
GO 
ALTER TABLE dbo.MovieGenre ADD CONSTRAINT MovieGenreInput CHECK (dbo.CheckGenreType(GenreID) = 0);

go;

-- computed colomn for age

alter table dbo.Person drop column if exists Age;
drop function if exists CalculateAge;

CREATE FUNCTION CalculateAge
(@DateOfBirth DATE)
RETURNS smallint
AS 
BEGIN
	declare @age smallint;

	set @age = DATEDIFF(hour, @DateOfBirth, GETDATE())/8766;
	
	return @age
END;

go;

ALTER TABLE dbo.Person ADD age AS dbo.CalculateAge(DateOfBirth);


--insert data file

-- person data
INSERT INTO Person 
(PersonID, PersonFirstName, PersonLastName, DateOfBirth, Gender, Nationality) VALUES
('D01', 'Christopher','Nolan','1970-07-30','Male','English'),
('D02', 'James','Cameron','1954-08-16','Male','Canadian'),
('D03', 'Damien','Chazelle','1985-01-19','Male','American'),
('D04', 'Baz','Luhrmann','1962-09-17','Male','Australian'),
('D05', 'Steven','Spielberg','1970-07-30','Male','American'),
('D06', 'Martin','Scorsese','1942-11-17','Male','American'),
('D07', 'Chris','Columbus','1958-09-10','Male','American'),
('D08', 'Jon','Favreau','1966-10-19','Male','American'),
('D09', 'Heywood','Allen','1935-11-30','Male','American'),
('D10', 'Quentin','Tarantino','1963-03-27','Male','American'),
('D11', 'Greta','Gerwig','1983-08-04','Female','American'),

('A01', 'Robert', 'Downey', '1965-04-04', 'Male', 'American'),
('A02', 'Terrence', 'Howard', '1969-03-1', 'Male', 'American'),
('A03', 'Sam', 'Worthington', '1976-08-02', 'Male', 'Australian'),
('A04', 'Leonardo', 'DiCaprio', '1974-11-11', 'Male', 'American'),
('A05', 'Kate', 'Winslet', '1975-10-05', 'Female', 'English'),
('A06', 'Elliot', 'Page', '1987-02-21', 'Male', 'Canadian'),
('A07', 'Jonah', 'Hill', '1983-12-20', 'Male', 'American'),
('A08', 'Daniel', 'Radcliffe', '1989-07-23', 'Male', 'English'),
('A09', 'Rupert', 'Grint', '1988-08-24', 'Male', 'English'),
('A10', 'Emma', 'Watson', '1990-04-15', 'Female', 'English'),
('A11', 'Ryan', 'Gosling', '1980-11-12', 'Male', 'Canadian'),

('R01', 'Chace','Bradshaw','19950601','Male','American'),
('R02', 'Braelyn','Cervantes','19811001','Male','American'),
('R03', 'April','Horne','19980601','Female','American'),
('R04', 'Sasha','Bolton','19930623','Female','American'),
('R05', 'Reese','Morse','20000201','Male','American'),
('R06', 'Jaylen','Mcclain','19900511','Male','American'),
('R07', 'Mohammad','Dunn','19850721','Male','American'),
('R08', 'Brynn','Mejia','19780126','Female','American'),
('R09', 'Tomas','Aguirre','20010315','Male','American'),
('R10', 'Francesca','Reed','19831201','Female','American')
;

SELECT * FROM Person;

-- director data
INSERT INTO Director
(DirectorID, DirectorBio) VALUES
('D01', 'Christopher Nolan is a British-American film director, producer, and screenwriter.'),
('D02', 'James Cameron is a Canadian filmmaker. Best known for making science fiction and epic films.'),
('D03', 'Damien Sayre Chazelle is an American film director, producer, and screenwriter.'),
('D04', 'Baz Luhrmann is an Australian director, writer, and producer.'),
('D05', 'Steven Allan Spielberg is an American film director, producer, and screenwriter.'),
('D06', 'Martin Charles Scorsese is an American film director, producer, and screenwriter.'),
('D07', 'Chris Joseph Columbus is an American filmmaker.'),
('D08', 'Jonathan Kolia Favreau is an American actor and filmmaker.'),
('D09', 'Heywood "Woody" Allen is an American film director, writer, actor, and comedian.'),
('D10', 'Quentin Jerome Tarantino is an American filmmaker, actor, film critic and author.'),
('D11', 'Greta Gerwig is an American actress, writer, and director.');

SELECT * FROM Director;

--actor data
INSERT INTO Actor
(ActorID, ActorBio) VALUES
('A01', 'Robert John Downey Jr. (born April 4, 1965) is an American actor and producer.'),
('A02', 'Terrence Dashon Howard (born March 11, 1969) is an American actor.'),
('A03', 'Samuel Henry John Worthington (born 2 August 1976) is an Australian actor.'),
('A04', 'Leonardo Wilhelm DiCaprio (born November 11, 1974) is an American actor and film producer.'),
('A05', 'Kate Elizabeth Winslet CBE (born 5 October 1975) is an English actress.'),
('A06', 'Elliot Page (born February 21, 1987) is a Canadian actor and producer.'),
('A07', 'Jonah Hill Feldstein (born December 20, 1983) is an American actor, filmmaker, and comedian. '),
('A08', 'Daniel Jacob Radcliffe (born 23 July 1989) is an English actor.'),
('A09', 'Rupert Alexander Lloyd Grint (born 24 August 1988) is an English actor. '),
('A10', 'Emma Charlotte Duerre Watson (born 15 April 1990) is an English actress and activist.'),
('A11', 'Ryan Gosling (born November 12, 1980) is a Canadian actor, musician, and animal welfare advocate. ');

SELECT * FROM Actor;

--reviewer data
OPEN SYMMETRIC KEY TestSymmetricKey 
DECRYPTION BY CERTIFICATE TestCertificate; 

insert into Reviewer values ('R01', 'ChaceBradshaw@gmail.com');
insert into Reviewer values ('R02', 'BraelynCervantes@gmail.com');
insert into Reviewer values ('R03', 'AprilHorne@gmail.com');
insert into Reviewer values ('R04', 'SashaBolton@gmail.com');
insert into Reviewer values ('R05', 'Reese@gmail.com');     
insert into Reviewer values ('R06', 'Jaylen@gmail.com');
insert into Reviewer values ('R07', 'Mohammad@gmail.com');
insert into Reviewer values ('R08', 'Brynn@gmail.com');
insert into Reviewer values ('R09', 'Tomas@gmail.com');
insert into Reviewer values ('R10', 'Francesca@gmail.com');

SELECT ReviewerID, Email, 
    CONVERT(varchar, DecryptByKey(Email)) AS 'Decrypted Email'  
FROM dbo.Reviewer; 

CLOSE SYMMETRIC KEY TestSymmetricKey;
DROP SYMMETRIC KEY TestSymmetricKey;
DROP CERTIFICATE TestCertificate;
DROP MASTER KEY;
       
--movie data
INSERT INTO Movie
(MovieID, DirectorID, MovieTitle, ReleaseDate, RunningTime, Language, Country) VALUES
('M01', 'D08', 'Iron Man', '2008-04-14', '02:06:00', 'English','United States'),
('M02', 'D02', 'Avatar', '2009-12-10', '02:42:00', 'English','United States'),
('M03', 'D02', 'Titanic', '1997-11-01', '03:15:00', 'English','United States'),
('M04', 'D01', 'Inception', '2010-04-14', '02:28:00', 'English','United States'),
('M05', 'D06', 'The Wolf of Wall Street', '2013-12-25', '03:00:00', 'English','United States'),
('M06', 'D04', 'The Great Gatsby', '2008-04-14', '02:06:00', 'English','United States'),
('M07', 'D07', 'Harry Potter and the Philosophers Stone', '2001-11-04', '02:32:00', 'English','United States'),
('M08', 'D08', 'Harry Potter and the Prisoner of Azkaban', '2002-11-15', '02:41:00', 'English','United States'),
('M09', 'D10', 'Once Upon a Time in Hollywood', '2019-05-21', '02:41:00', 'English','United States'),
('M10', 'D03', 'La La Land', '2016-08-31', '02:08:00', 'English','United States'),
('M11', 'D11', 'Little Women', '2019-12-25', '02:15:00', 'English','United States');

SELECT * FROM Movie;

--genre data
INSERT INTO Genre
(GenreID, GenreName) VALUES
('G01', 'SuperHero'),
('G02', 'Action'),
('G03', 'Romance'),
('G04', 'Science Fiction'),
('G05', 'Drama'),
('G06', 'Historical Fiction'),
('G07', 'Adventure'),
('G08', 'Fantasy'),
('G09', 'Comedy'),
('G10', 'Musical');

SELECT * FROM Genre;

--production company data
INSERT INTO ProductionCompany
(ProductionCompanyID, ProductionCompanyName, District, City, State, PostalCode, Country) VALUES
('C01', 'Marvel Studios','500 South Buena Vista Street', 'Burbank', 'CA', 91521, 'United States'),
('C02', '20th Century Fox', '10201 W Pico Blvd', 'Los Angeles', 'CA',90064, 'United States'),
('C03', 'Paramount Pictures', '5555 Melrose Ave', 'Los Angeles', 'CA',90038, 'United States'),
('C04', 'Warner Bros. Pictures', '4000 Warner Blvd', 'Burbank', 'CA',91522, 'United States'),
('C05', 'Red Granite Pictures', '10960 Wilshire Blvd', 'Los Angeles', 'CA',90024, 'United States'),
('C06', 'Village Roadshow Pictures', '10100 Santa Monica Blvd', 'Los Angeles', 'CA',90067, 'United States'),
('C07', 'Universal Pictures', '100 Universal City Plaza', 'Universal City', 'CA',91608, 'United States'),
('C08', 'Sony Pictures', '10202 West Washington Boulevard', 'Culver City', 'CA',90232, 'United States'),
('C09', 'Columbia Pictures', '10202 Washington Blvd', 'Culver City', 'CA',90232, 'United States'),
('C10', 'Summit Entertainment', '2700 Colorado Ave Ste 200', 'Santa Monica', 'CA',90404, 'United States');

SELECT * FROM ProductionCompany;

--award data
INSERT INTO Award 
(AwardID, AwardName, AwardDescription) VALUES 
   ('A01','Saturn Award for Best Science Fiction Film', 'The Saturn Award for Best Science Fiction Film is one of the Saturn Awards that has been presented annually since 1972 by Academy of Science Fiction, Fantasy and Horror Films to the best film in the science fiction genre of the previous year'),
   ('A02','Saturn Award for Best Actor','The Saturn Award for Best Actor is an award presented annually by the Academy of Science Fiction, Fantasy & Horror Films to honor the top works in science fiction, fantasy, and horror in film, television, and home video.'),
   ('A03','Saturn Award for Best Director','The Saturn Award for Best Director is one of the annual awards given by the American Academy of Science Fiction, Fantasy & Horror Films.'),
   ('A04','Satellite Award for Best Film Editing','The Satellite Award for Best Editing is one of the annual Satellite Awards given by the International Press Academy.'),
   ('A05','Central Ohio Film Critics Association Award for Actor of the Year','Annual film awards held in Columbus, Ohio'),
   ('A06','Satellite Award for Best DVD Extra','The Satellite Award for Outstanding Overall Blu-ray/DVD is an annual award given by the International Press Academy as one of its Satellite Awards.'),
   ('A07','Irish Film and Television Audience Award for Best International Actor','This award is given for distinguished service to an individual who has demonstrated those qualities that most exemplify the standards of leadership established by Rick Reeves during his 25 years of commitment to the Transportation Industry.'),
   ('A08','MTV Movie Award for Best Summer Movie','The MTV Movie & TV Awards is a film and television awards show presented annually on MTV.'),
   ('A09','Academy Award for Best Cinematography','The Academy Award for Best Cinematography is an Academy Award awarded each year to a cinematographer for work on one particular motion picture.'),	
   ('A10','Academy Award for Best Visual Effects','The Academy Award for Best Visual Effects is an Academy Award given for the best achievement in visual effects.'),
   ('A11','Empire Award for Best Film','The Empire Award for Best Film is an Empire Award presented annually by the British film magazine Empire to honor the best film of the previous year. The Empire Award for Best Film is one of five ongoing awards which were first introduced at the 1st Empire Awards ceremony in 1996 with Braveheart receiving the award.'),
   ('A12','Academy Award for Best Picture','The Academy Award for Best Picture is one of the Academy Awards presented annually by the Academy of Motion Picture Arts and Sciences since the awards debuted in 1929.'),
   ('A13','Academy Award for Best Music','The Academy Award for Best Original Score is an award presented annually by the Academy of Motion Picture Arts and Sciences to the best substantial body of music in the form of dramatic underscoring written specifically for the film by the submitting composer.'),
   ('A14','Screen Actors Guild Award for Outstanding Performance by a Female Actor in a Supporting Role','The Screen Actors Guild Award for Outstanding Performance by a Female Actor in a Supporting Role in a Motion Picture is an award given by the Screen Actors Guild to honor the finest acting achievements in film.'),
   ('A15','Academy Award for Best Directing','The Academy Award for Best Director is an award presented annually by the Academy of Motion Picture Arts and Sciences. '),
   ('A16','Academy Award for Best Production Design','The Academy Award for Best Production Design recognizes achievement for art direction in film. '),
   ('A17','MTV Movie & TV Award for Most Frightened Performance','This is a following list for the MTV Movie Award winners for Best Scared-As-Shit Performance.'),
   ('A18','Academy Award for Best Sound Mixing','The Academy Award for Best Sound is an Academy Award that recognizes the finest or most euphonic sound mixing, recording, sound design, and sound editing. '),
   ('A19','Saturn Award for Best Music','The Saturn Award for Best Music is an award presented by the Academy of Science Fiction, Fantasy and Horror Films to the best music in film.'),
   ('A20','American Society of Cinematographers Award for Outstanding Achievement in Cinematography in Theatrical Releases','The following is a list of cinematographers who have won and been nominated for the American Society of Cinematographers Award for Outstanding Achievement in Theatrical Releases, which is given annually by the American Society of Cinematographers.'),
   ('A21','Academy Award for Best Sound Editing','The Academy Award for Best Sound Editing was an Academy Award granted yearly to a film exhibiting the finest or most aesthetic sound design or sound editing.'),
   ('A22','Screen Actors Guild Award for Outstanding Performance by a Stunt Ensemble in a Motion Picture','The Screen Actors Guild Award for Outstanding Performance by a Stunt Ensemble in a Motion Picture is one of the awards given by the Screen Actors Guild.'),
   ('A23','Hugo Award for Best Dramatic Presentation, Long Form','The Long Form award is for "a dramatized production in any medium, including film, television, radio, live theater, computer games or music.'),
   ('A24','MTV Movie Award for Best Gut-Wrenching Performance','This is a following list of the MTV Movie Award winners and nominees for Best WTF Moment, first awarded in 2009.'),
   ('A25','AFI Movies of the Year','The American Film Institute Awards are awards presented by the American Film Institute to recognize the top 10 films and television programs of the year.'),
   ('A26','Critic Choice Movie Award for Best Actor in a Comedy','The Critics Choice Movie Award for Best Actor in a Comedy is one of the awards given to people working in the motion picture industry by the Broadcast Film Critics Association at their annual Critics Choice Movie Awards.'),
   ('A27','Golden Globe Award for Best Actor – Motion Picture Musical or Comedy','The Golden Globe Award for Best Actor in a Motion Picture – Musical or Comedy is a Golden Globe Award presented annually by the Hollywood Foreign Press Association.'),
   ('A28','MTV Movie & TV Award for Best Comedic Performance','This is a following list of the MTV Movie Award winners and nominees for Best Comedic Performance. '),
   ('A29','Empire Award for Best Female Newcomer','The Empire Award for Best Female Newcomer is an Empire Award presented annually by the British film magazine Empire to honour an actress who has delivered a breakthrough performance while working within the film industry.'),
   ('A30','National Board of Review Award for Best Adapted Screenplay','The National Board of Review Award for Best Adapted Screenplay is an annual film award given by the National Board of Review of Motion Pictures.'),
   ('A31','Academy Award for Best Costume Design','The Academy Award for Best Costume Design is one of the Academy Awards presented annually by the Academy of Motion Picture Arts and Sciences for achievement in film costume design.'),
   ('A32','ADG Excellence in Production Design Awards - Period Film','The Art Directors Guild Award for Excellence in Production Design for a Period Film is one of the annual awards given by the Art Directors Guild starting from 2000.'),
   ('A33','AACTA Award for Best Supporting Actor in Film','The Australian Film Institute Award for Best Actor in a Supporting Role is an award in the annual Australian Film Institute Awards. It has been awarded annually since 1974.'),
   ('A34','AACTA Award for Best Film','The AACTA Award for Best Film is an award presented by the Australian Academy of Cinema and Television Arts, a non-profit organisation whose aim is to "identify, award, promote, and celebrate Australia greatest achievements in film and television.'),
   ('A35','AACTA Award for Best Direction in Film','The AACTA Award for Best Direction is an award presented by the Australian Academy of Cinema and Television Arts, a non-profit organisation whose aim is to "identify, award, promote and celebrate Australia greatest achievements in film and television."'),
   ('A36','Young Artist Award for Best Leading Young Actress in a Feature Film','The Young Artist Award for Best Performance by a Leading Young Actress in a Feature Film is one of the Young Artist Awards presented annually by the Young Artist Association to recognize a young actress under the age of 21, who has delivered an outstanding performance in a leading role while working within the film industry.'),
   ('A37','Satellite Special Achievement Award for Outstanding New Talent','The Satellite Award for Outstanding New Talent was a special achievement award given by the International Press Academy between 1996 and 2012.'),
   ('A38','Saturn Award for Best Costume Design','The Saturn Awards for Best Costume Design are American awards presented annually by the Academy of Science Fiction, Fantasy and Horror Films; they were created to honor science fiction, fantasy, and horror in film, but have since grown to reward other films belonging to genre fiction, as well as television and home media releases.'),
   ('A39','BFCA Critics Choice Award for Best Family Film','The Broadcast Film Critics Association Award for Best Family Film is a retired award that was handed out from 1995 to 2007.'),
   ('A40','Teen Choice Award for Film - Choice Movie: Action Adventure','Action Adventure is one of the awards presented every year at the Teen Choice Awards ceremony.'),
   ('A41','BAFTA Orange Film of the Year','The British Academy Film Television Awards, more commonly known as the BAFTA Film Awards is an annual award show hosted by the British Academy of Film and Television Arts (BAFTA) to honour the best British and international contributions to film.'),
   ('A42','Academy Award for Best Supporting Actor','The Academy Award for Best Supporting Actor is an award presented annually by the Academy of Motion Picture Arts and Sciences.'),
   ('A43','Golden Globe Award for Best Screenplay - Motion Picture','The Golden Globe Award for Best Screenplay – Motion Picture is a Golden Globe Award given by the Hollywood Foreign Press Association.'),
   ('A44','Golden Globe Award for Best Supporting Actor – Motion Picture','The Golden Globe Award for Best Supporting Actor – Motion Picture is a Golden Globe Award that was first awarded by the Hollywood Foreign Press Association in 1944 for a performance in a motion picture released in the previous year.'),
   ('A45','Golden Globe Award for Best Motion Picture – Musical or Comedy','The Golden Globe Award for Best Motion Picture – Musical or Comedy is a Golden Globe Award that has been awarded annually since 1952 by the Hollywood Foreign Press Association.'),
   ('A46','Academy Award for Best Actress in a Leading Role','The Academy Award for Best Actress is an award presented annually by the Academy of Motion Picture Arts and Sciences.'),
   ('A47','Golden Globe Award for Best Actress – Motion Picture – Musical or Comedy','The Golden Globe Award for Best Actress in a Motion Picture – Comedy or Musical is a Golden Globe Award that was first awarded by the Hollywood Foreign Press Association as a separate category in 1951.');

 SELECT * FROM dbo.Award; 
 --movie award data 
INSERT INTO MovieAward
(Movie_AwardID ,AwardID, MovieID, IssueDate) VALUES 
   ('MA01','A01','M01','2009-06-25'),
   ('MA02','A02','M01','2009-06-25'),
   ('MA03','A03','M01','2009-06-25'),
   ('MA04','A04','M01','2008-12-14'),
   ('MA05','A05','M01','2009-01-08'),
   ('MA06','A06','M01','2008-12-14'),
   ('MA07','A07','M01','2009-02-14'),
   ('MA08','A08','M01','2008-06-01'),
   ('MA10','A10','M02','2010-03-07'),
   ('MA11','A11','M02','2010-03-28'),
   ('MA12','A12','M03','1998-03-23'),
   ('MA13','A13','M03','1998-03-23'),
   ('MA14','A08','M03','1998-05-30'),
   ('MA15','A09','M03','1998-03-23'),
   ('MA16','A10','M03','1998-03-23'),
   ('MA17','A14','M03','1998-03-08'),
   ('MA18','A15','M03','1998-03-23'),
   ('MA19','A16','M03','1998-03-23'),
   ('MA20','A17','M04','2011-06-05'),
   ('MA21','A10','M04','2011-02-27'),
   ('MA22','A18','M04','2011-02-27'),
   ('MA23','A19','M04','2011-06-23'),
   ('MA24','A20','M04','2011-02-13'),
   ('MA25','A11','M04','2011-03-25'),
   ('MA26','A09','M04','2011-02-27'),
   ('MA27','A21','M04','2011-02-27'),
   ('MA28','A22','M04','2011-01-30'),
   ('MA29','A23','M04','2011-08-17'),
   ('MA30','A24','M05','2014-04-13'),
   ('MA31','A25','M05','2014-12-08'),
   ('MA32','A26','M05','2014-01-16'),
   ('MA33','A27','M05','2014-01-12'),
   ('MA34','A28','M05','2014-04-13'),
   ('MA35','A29','M05','2014-03-30'),
   ('MA36','A30','M05','2013-12-04'),
   ('MA37','A16','M06','2014-03-02'),
   ('MA38','A31','M06','2014-03-02'),
   ('MA39','A32','M06','2014-02-08'),
   ('MA40','A33','M06','2014-01-28'),
   ('MA41','A34','M06','2014-01-28'),
   ('MA42','A35','M06','2014-01-28'),
   ('MA43','A36','M07','2002-04-07'),
   ('MA44','A37','M07','2002-01-29'),
   ('MA45','A38','M07','2002-06-10'),
   ('MA46','A39','M07','2002-01-11'),
   ('MA47','A40','M08','2004-08-08'),
   ('MA48','A41','M08','2005-02-12'),
   ('MA49','A16','M09','2020-02-09'),
   ('MA50','A42','M09','2020-02-09'),
   ('MA51','A43','M09','2020-01-05'),
   ('MA52','A44','M09','2020-01-05'),
   ('MA53','A45','M09','2020-01-05'),
   ('MA54','A46','M10','2017-02-26'),
   ('MA55','A13','M10','2017-02-26'),
   ('MA56','A15','M10','2017-02-26'),
   ('MA57','A09','M10','2017-02-26'),
   ('MA58','A45','M10','2017-01-08'),
   ('MA59','A16','M10','2017-02-26'),
   ('MA60','A47','M10','2017-01-08');
  	
  
 SELECT * FROM dbo.MovieAward;   

--movie actor role data, the combination of movieID, actorID, roleName should be unique.
INSERT INTO MovieActor 
(RoleID, MovieID, ActorID, RoleName, RoleDescription) VALUES
('R01', 'M01', 'A01', ' Tony Stark', 'The CEO of Stark Industries and chief weapons manufacturer for the U.S. military.'),
('R02', 'M01', 'A02', 'James Rhodes', 'A friend of Starks and the liaison between Stark Industries and the United States Air Force.'),
('R03', 'M02', 'A03', 'Jake Sully', 'A disabled former Marine who becomes part of the Avatar Program'),
('R04', 'M03', 'A04', 'Jack Dawson', 'An itinerant, poor orphan, who has travelled the world'),
('R05', 'M03', 'A05', 'Rose DeWitt', 'A 17-year-old girl, originally from Philadelphia.'),
('R06', 'M04', 'A04', 'Dom Cobb', 'A professional thief who specializes in conning secrets from his victims.'),
('R07', 'M04', 'A06', 'Ariadne', 'A graduate student who is recruited to construct the various dreamscapes.'),
('R08', 'M05', 'A04', 'Jordan Belfort', 'An American entrepreneur, speaker, former stockbroker and convicted felon'),
('R09', 'M05', 'A07', 'Donnie Azoff', 'An American businessman and former stock broker.'),
('R10', 'M06', 'A04', 'Jay Gatsby', 'A mysterious millionaire who hosts wild parties at his house.'),
('R11', 'M07', 'A08', 'Harry Potter', 'A boy who learns of his own fame as a wizard known to have survived.'),
('R12', 'M07', 'A09', 'Ron Weasley', 'Harrys best friend at Hogwarts and a younger member of the Weasley family.'),
('R13', 'M07', 'A10', 'Hermione Granger','Harrys other best friend and the trios brains.'),
('R14', 'M08', 'A08', 'Harry Potter', 'A boy who learns of his own fame as a wizard known to have survived.'),
('R15', 'M08', 'A09', 'Ron Weasley', 'Harrys best friend at Hogwarts and a younger member of the Weasley family.'),
('R16', 'M08', 'A10', 'Hermione Granger','Harrys other best friend and the trios brains.'),
('R17', 'M09', 'A04', 'Rick Dalton', 'A faded television actor strives to achieve fame and success.'),
('R18', 'M10', 'A11', 'Sebastian Wilder', 'A pianist falls in love with an actress.'),
('R19', 'M11', 'A10', 'Meg March', 'Meg is sweet-natured, dutiful, and not at all flirtatious.');

SELECT * FROM dbo.MovieActor; 

--movie genre data
INSERT INTO MovieGenre
(MovieID, GenreID) VALUES
('M01','G01'),
('M02','G02'),
('M03','G03'),
('M04','G04'),
('M05','G05'),
('M06','G06'),
('M07','G07'),
('M07','G08'),
('M08','G07'),
('M08','G08'),
('M09','G09'),
('M10','G10'),
('M11','G03');

SELECT * FROM MovieGenre;

--movie production data
INSERT INTO MovieProduction 
(MovieID, ProductionCompanyID) VALUES
('M01','C01'),
('M02','C02'),
('M03','C03'),
('M04','C04'),
('M05','C05'),
('M06','C06'),
('M07','C04'),
('M08','C04'),
('M09','C09'),
('M10','C10'),
('M11','C09');

SELECT * FROM MovieProduction;

--movie rating data
insert into Rating 
values 
   ('M01','R01','5','Iron Man is the best!','20190908','20190910'),
   ('M02','R05','4','I was entirely immersed and immensely amazed. Avatar is a pure cinematic magic.','20200105','20200105'),
   ('M03','R03','5','Visually, the movie is undeniably impressive; there"s no question where all the money went.','20051218','20051218'),
   ('M04','R02','3','The film has none of the vivid unpredictable banality of dreams or life.','20150719','20150720'),
   ('M05','R04','5','Conflict and, most surprisingly, consequences, are absent.','20160829','20160829'),
   ('M06','R06','2','The film does nothing to beat against the current. ','20080505','20080505'),
   ('M07','R07','5','First Potter movie is a magical ride but also intense.','20021215','20021215'),
   ('M08','R10','5','Prisoner of Azkaban baffled me and completely floored me...it shows that Harry Potter ages with people.','20030214','20020214'),
   ('M09','R09','3','This film could have been so much shorter and just as good','20190605','20190605'),
   ('M10','R08','4','It is a simple tale told with such visual inventiveness it reminds audience the power inherent in cinema.','20211120','20211120'),
   ('M01','R03','5','A movie that started MCU and to this day it is one of the best MCU movies. Robert Downey Jr. is amazing as Iron Man.','20100109','20100109'),
   ('M01','R08','3','Like the very much anti-imperialist slant Iron Man is somewhat going for, but I do find it a bit confused.','20200105','20200105'),
   ('M01','R04','5','A brilliant way to start off the MCU bringing a fresh take that is rarely ever seen in future mcu movies.','20220403','20220405'),
   ('M01','R10','4','Great origins story and good character build up.','20121003','20121003'),
   ('M01','R02','5','If you don''t like Iron Man, then you should stop going to movies.','20200912','20200912'),
   ('M01','R09','5','It''s enjoyable to see a quality superhero dynamically and enthusiastically rendered.','20100706','20100706'),
   ('M06','R05','5','It is not the novel, no, but happy to report, the madly embattled result is a real movie.','20180405','20180405'),
   ('M06','R09','5','Like flicking through the pages of Vogue whilst sipping a martini.','20170904','20170904'),
   ('M06','R01','3','It"s a headache-inducing mishmash of waving curtains, hyperactive fades, aggressive zooms.','20160621','20160621'),
   ('M06','R07','3','This is fantastically enjoyable, and a blast.','20180921','20180921'),
   ('M10','R07','4','It makes it more difficult to just let something like La La Land just passively wash over you.','20170920','20170920'),
   ('M10','R05','5','The Power of Love vs. White Saviors.','20211002','20211020'),
   ('M10','R01','5','One of the most magical, most heartfelt and most majestic movies I''ve ever seen in my whole life!','20200531','20200531'),
   ('M10','R06','5','La La Land is a film that makes us dreamers remember that anything is possible.','20220214','20220214');
   
SELECT * FROM dbo.Rating;      


-- presenting views

select *
from dbo.ActorCastRankWithTies;

select *
from dbo.topReviewMovie;




