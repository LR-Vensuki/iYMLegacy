/**
 * File              : ThemesViewController.m
 * Theme picker with live previews, and signing out.
 */

#import "ThemesViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "YMTheme.h"
#import "YandexConnect.h"

enum { kSectionThemes, kSectionAccount, kSectionAbout, kSectionCount };

@implementation ThemesViewController

- (id)init
{
	if ((self = [super initWithStyle:UITableViewStyleGrouped]))
		self.title = @"Оформление";
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	[[YMTheme current] styleController:self];
}

/* A miniature of the theme: nav bar, a row with the accent, the tab bar. */
- (UIImage *)previewForTheme:(YMTheme *)t
{
	CGSize size = CGSizeMake(54, 64);
	UIImage *nav = [t navBackgroundWithHeight:44];
	UIImage *tab = [t tabBackground];
	return [YMDraw imageWithSize:size opaque:NO drawing:^(CGContextRef ctx, CGRect rect) {
		UIBezierPath *frame = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect, 1, 1) cornerRadius:6];
		CGContextSaveGState(ctx);
		[frame addClip];
		[t.background setFill];
		CGContextFillRect(ctx, rect);
		[nav drawInRect:CGRectMake(0, 0, size.width, 16)];
		[tab drawInRect:CGRectMake(0, size.height - 14, size.width, 14)];
		[[YMDraw blend:t.cell with:t.text amount:0.08] setFill];
		CGContextFillRect(ctx, CGRectMake(0, 20, size.width, 12));
		[YMDraw fillRect:CGRectMake(0, 34, size.width, 12) inContext:ctx
		          colors:@[t.cellSelectedTop, t.cellSelectedBottom] locations:NULL];
		[[t.text colorWithAlphaComponent:0.5] setFill];
		CGContextFillRect(ctx, CGRectMake(5, 24, 26, 4));
		[[t.accentText colorWithAlphaComponent:0.8] setFill];
		CGContextFillRect(ctx, CGRectMake(5, 38, 30, 4));
		UIBezierPath *g = [YMDraw pathForGlyph:YMGlyphNote inRect:CGRectMake(21, size.height - 13, 12, 12)];
		[YMDraw fillPath:g inContext:ctx colors:@[t.tabSelectedTop, t.tabSelectedBottom]];
		CGContextRestoreGState(ctx);
		[YMRGBA(0, 0, 0, 0.35) setStroke];
		[frame stroke];
	}];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return kSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == kSectionThemes) return YMThemeCount;
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == kSectionThemes) return @"Тема";
	if (section == kSectionAccount) return @"Аккаунт";
	return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	if (!title.length)
		return nil;
	return [[YMTheme current] sectionHeaderWithTitle:title width:tableView.bounds.size.width grouped:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	return [self tableView:tableView titleForHeaderInSection:section].length ? 40 : 12;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
	NSString *text = [self tableView:tableView titleForFooterInSection:section];
	if (!text.length)
		return nil;
	YMTheme *t = [YMTheme current];
	UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, 6, tableView.bounds.size.width - 40, 40)];
	l.backgroundColor = [UIColor clearColor];
	l.numberOfLines = 2;
	l.textAlignment = NSTextAlignmentCenter;
	l.font = [UIFont systemFontOfSize:13];
	l.textColor = t.subtext;
	l.shadowColor = (t.kind == YMThemeYandexDark) ? YMRGBA(0, 0, 0, 0.9) : YMRGBA(255, 255, 255, 0.7);
	l.shadowOffset = CGSizeMake(0, 1);
	l.text = text;
	UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 52)];
	[v addSubview:l];
	return v;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
	return [self tableView:tableView titleForFooterInSection:section].length ? 52 : 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	if (section == kSectionAbout)
		return [NSString stringWithFormat:@"iYMLegacy %@\nLegacyReborn Project, форк iYMLegacy от igkuzm",
		        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return indexPath.section == kSectionThemes ? 76 : 44;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	YMTheme *current = [YMTheme current];
	if (indexPath.section == kSectionThemes) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"theme"];
		if (!cell)
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"theme"];
		YMTheme *t = [YMTheme themeWithKind:(YMThemeKind)indexPath.row];
		cell.textLabel.text = t.name;
		cell.detailTextLabel.text = t.subtitle;
		cell.detailTextLabel.numberOfLines = 2;
		cell.imageView.image = [self previewForTheme:t];
		cell.accessoryType = (t.kind == current.kind) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
		return cell;
	}
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"button"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"button"];
	cell.textLabel.textAlignment = NSTextAlignmentCenter;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.imageView.image = nil;
	if (indexPath.section == kSectionAccount) {
		BOOL signedIn = [[NSUserDefaults standardUserDefaults] valueForKey:@"token"] != nil;
		cell.textLabel.text = signedIn ? @"Выйти из аккаунта" : @"Войти";
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	} else {
		cell.textLabel.text = @"github.com/LR-Vensuki/iYMLegacy";
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	YMTheme *t = [YMTheme current];
	[t styleCell:cell];
	cell.imageView.layer.cornerRadius = 0;
	if (indexPath.section == kSectionAccount)
		cell.textLabel.textColor = YMRGB(200, 40, 30);
	if (indexPath.section == kSectionAbout) {
		cell.textLabel.font = [UIFont systemFontOfSize:14];
		cell.textLabel.textColor = t.subtext;
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == kSectionThemes) {
		if ((YMThemeKind)indexPath.row != [YMTheme current].kind)
			[YMTheme setCurrentKind:(YMThemeKind)indexPath.row];
		return;
	}
	if (indexPath.section == kSectionAccount) {
		if (![[NSUserDefaults standardUserDefaults] valueForKey:@"token"]) {
			[YandexConnect signOut];
			return;
		}
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Выйти из аккаунта?"
				message:@"Чтобы снова слушать музыку, нужно будет войти по коду."
				delegate:self cancelButtonTitle:@"Отмена" otherButtonTitles:@"Выйти", nil];
		[alert show];
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == 1) {
		[YandexConnect signOut];
		[self.tableView reloadData];
	}
}

@end

// vim:ft=objc
