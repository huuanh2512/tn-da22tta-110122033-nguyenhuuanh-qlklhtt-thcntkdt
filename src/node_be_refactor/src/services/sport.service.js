const sportRepository = require('../repositories/sport.repository');

class SportService {
  _formatSportResponse(sport) {
    return {
      id: sport._id.toString(),
      name: sport.name,
      description: sport.description || '',
      iconUrl: sport.icon_url || '',
      teamSize: sport.team_size || 0,
      active: sport.active
    };
  }

  async querySports(filters, skip = 0, limit = 20) {
    const query = {};
    
    if (filters.name) {
      query.name = new RegExp(filters.name, 'i');
    }
    if (filters.active !== undefined) {
      query.active = filters.active === 'true' || filters.active === true;
    }

    const [sports, total] = await Promise.all([
      sportRepository.findMany(query, parseInt(skip), parseInt(limit)),
      sportRepository.count(query)
    ]);

    return {
      items: sports.map(s => this._formatSportResponse(s)),
      total: total
    };
  }

  async createSport(data) {
    const sportData = {
      name: data.name,
      description: data.description || '',
      icon_url: data.iconUrl || '',
      team_size: data.teamSize || 0,
      active: data.active !== undefined ? data.active : true
    };

    const newSport = await sportRepository.create(sportData);
    return { sport: this._formatSportResponse(newSport) };
  }

  async updateSport(id, data) {
    const updateData = {};
    
    if (data.name !== undefined) updateData.name = data.name;
    if (data.description !== undefined) updateData.description = data.description;
    if (data.iconUrl !== undefined) updateData.icon_url = data.iconUrl;
    if (data.teamSize !== undefined) updateData.team_size = data.teamSize;
    if (data.active !== undefined) updateData.active = data.active;

    const updatedSport = await sportRepository.updateById(id, updateData);
    if (!updatedSport) throw new Error('Sport not found');
    
    return { sport: this._formatSportResponse(updatedSport) };
  }

  async deleteSport(id) {
    const deleted = await sportRepository.deleteById(id);
    if (!deleted) throw new Error('Sport not found');
    return true;
  }
}

module.exports = new SportService();
