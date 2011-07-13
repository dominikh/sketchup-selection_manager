# Copyright (C) 2011 by Dominik Honnef
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require "sketchup.rb"

module DominikH
  module SelectionManager
    @selections = {}
    @sortation  = {}
    @max        = 0

    def self.sortation; @sortation; end

    def self.set_sortation(hash)
      @sortation = Hash[*hash.flatten]
      @max = @sortation[sorted_all.last.first]
    end

    def self.all
      @selections
    end

    def self.sorted_all
      @selections.sort {|sel1, sel2| @sortation[sel1.first] <=> @sortation[sel2.first]}
    end

    def self.clear
      @selections.clear
      @sortation.clear
      @max = 0
    end

    def self.create(name, sel = nil)
      if sel
        selection = Selection.from_su_selection(name, sel)
      else
        selection = Selection.new(name)
      end

      @selections[name] = selection
      @sortation[name] = @max += 1
      selection
    end

    def self.delete(selection)
      @selections.delete(selection.name)
    end

    class MyAppObserver < Sketchup::AppObserver
      def onNewModel(model)
        SelectionManager.clear
        model.add_observer(DominikH::SelectionManager::MyModelObserver.new)
      end
      alias_method :onOpenModel, :onNewModel
    end

    class MyModelObserver < Sketchup::ModelObserver
      def onPreSaveModel(model)
        onPostSaveModel(model) # make sure we have no old attributes left (e.g. from a previous save/load cycle)
        DominikH::SelectionManager.all.values.each do |selection|
          selection.save_to_entities
        end

        model.set_attribute("dh_selection_manager", "sortation", DominikH::SelectionManager.sortation.to_a)
      end

      def onPostSaveModel(model)
        DominikH::SelectionManager.all.values.map{|s| s.items}.flatten.uniq.each do |entity|
          entity.delete_attribute("dh_selection_manager", "groups")
        end
      end
    end

    class Selection
      class << self
        def from_su_selection(name, selection)
      instance = new(name)
          instance.merge!(selection)
          instance
        end
      end

      attr_reader :name
      attr_reader :items
      def initialize(name)
        @name  = name
        @items = []
      end

      def save_to_entities
        @items.each do |entity|
          groups = entity.get_attribute("dh_selection_manager", "groups") || []
          groups << @name
          entity.set_attribute("dh_selection_manager", "groups", groups)
        end
      end

      def merge!(selection)
        @items.concat(selection.to_a)
      end

      def unmerge!(selection)
        selection.each do |entity|
          @items.delete(entity)
        end
      end

      def update!
        to_delete = @items.select {|item| item.deleted?}
        unmerge!(to_delete)
      end

      def select
        selection = Sketchup.active_model.selection
        selection.clear

        begin
          selection.add(@items)
        rescue TypeError
          if UI.messagebox("Some entities in this selection do not exist anymore. Update selection?", MB_YESNO) == 6 # yes
            update!
            self.select
          else
            selection.clear
          end
        end
      end
    end
  end
end

if !file_loaded?(__FILE__)
  UI.add_context_menu_handler do |context_menu|
    context_menu.add_separator

    selection_menu = context_menu.add_submenu("Selection Manager")
    selection_menu.add_item("Add new selection") do
      name = (UI.inputbox(["Select a name"], [], "Save a new selection") || []).first
      if name.to_s.empty?
        UI.messagebox("Empty name entered -> Cancelled creation")
        next
      end

      name.strip!

      action = :create
      # if a selection with this name already exists, first ask if we
      # should overwrite it. if the answer is no, ask if we should
      # append to it. Answering "no" twice, or cancel at any one
      # point, will cancel the operation
      if DominikH::SelectionManager.all.has_key?(name)
        ret = UI.messagebox("A selection with this name already exists. Overwrite it?", MB_YESNOCANCEL)
        case ret
        when 7 # no
          ret2 = UI.messagebox("Add to the existing selection instead?", MB_YESNOCANCEL)
          case ret2
          when 6 # yes
            action = :append
          when 7, 2 # no, cancel
            next
          end
        when 2 # cancel
          next
        end
      end

      case action
      when :create
        DominikH::SelectionManager.create(name, Sketchup.active_model.selection)
      when :append
        DominikH::SelectionManager.all[name].merge!(Sketchup.active_model.selection)
      end
    end

    selection_menu.add_item("Load selections from model") do
      DominikH::SelectionManager.clear
      groups = Hash.new{|h, k| h[k] = []}
      Sketchup.active_model.entities.each do |entity|
        (entity.get_attribute("dh_selection_manager", "groups") || []).each do |group|
          entity.delete_attribute("dh_selection_manager", "groups")
          groups[group] << entity
        end
      end

      groups.each do |name, entities|
        DominikH::SelectionManager.create(name, entities)
      end

      DominikH::SelectionManager.set_sortation(Sketchup.active_model.get_attribute("dh_selection_manager", "sortation"))
    end

    selection_menu.add_separator

    DominikH::SelectionManager.sorted_all.each do |name, selection|
      submenu = selection_menu.add_submenu(name)
      submenu.add_item("Select") do
        selection.select
      end

      submenu.add_item("Add to selection") do
        selection.merge!(Sketchup.active_model.selection)
      end

      submenu.add_item("Remove from selection") do
        selection.unmerge!(Sketchup.active_model.selection)
      end

      submenu.add_separator

      submenu.add_item("Remove") do
        DominikH::SelectionManager.delete(selection)
      end
    end

    context_menu.add_separator
  end

  Sketchup.add_observer(DominikH::SelectionManager::MyAppObserver.new)
  Sketchup.active_model.add_observer(DominikH::SelectionManager::MyModelObserver.new)
end

file_loaded(__FILE__)
