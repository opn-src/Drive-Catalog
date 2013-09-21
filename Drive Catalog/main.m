//
//  main.m
//  Drive Catalog
//
//  Created by Pierce Corcoran on 9/21/13.
//  Copyright (c) 2013 Pierce Corcoran. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <MacRuby/MacRuby.h>

int main(int argc, char *argv[])
{
    return macruby_main("rb_main.rb", argc, argv);
}
